import express from 'express';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import WebSocket, { WebSocketServer } from 'ws';
import OpenAI from 'openai';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import fs from 'fs';

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/qqchatbot';
const WS_PORT = parseInt(process.env.WS_PORT || '3001', 10);
const API_PORT = parseInt(process.env.API_PORT || '3002', 10);
const JWT_SECRET = process.env.JWT_SECRET || 'please-change-me';
const ADMIN_USER = process.env.ADMIN_USER || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';
const ENV_FILE = './.env';

// --------- Mongo Models ---------
await mongoose.connect(MONGODB_URI, { autoIndex: true });
console.log('✅ MongoDB 已连接');

const PersonaSchema = new mongoose.Schema(
  {
    order: { type: Number, default: 1 },
    name: { type: String, required: true },
    prompt: { type: String, required: true },
    isDefault: { type: Boolean, default: false },
  },
  { timestamps: true }
);

const ConfigSchema = new mongoose.Schema(
  {
    provider: { type: String, default: 'openai' }, // openai | deepseek
    model: { type: String, default: 'gpt-3.5-turbo' },
    maxTokens: { type: Number, default: 1000 },
    temperature: { type: Number, default: 0.7 },
    maxHistoryLength: { type: Number, default: 20 },
    summaryThreshold: { type: Number, default: 10 },
    globalPrompt: {
      type: String,
      default: '你必须遵守以下规则：1. 使用中文回复 2. 回复简洁明了',
    },
    enableStream: { type: Boolean, default: true },
  },
  { timestamps: true }
);

const MessageSchema = new mongoose.Schema(
  {
    role: { type: String, enum: ['user', 'assistant'], required: true },
    content: { type: String, required: true },
    time: { type: Date, default: Date.now },
    tokens: { type: Number, default: 0 },
  },
  { _id: false }
);

const ChatUserSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true },
    nickname: { type: String, default: '' },
    messageCount: { type: Number, default: 0 },
    tokenCount: { type: Number, default: 0 },
    lastChatTime: { type: Date, default: null },
    messages: { type: [MessageSchema], default: [] },
  },
  { timestamps: true }
);

const StatsSchema = new mongoose.Schema(
  {
    totalMessages: { type: Number, default: 0 },
    todayMessages: { type: Number, default: 0 },
    totalTokens: { type: Number, default: 0 },
    todayTokens: { type: Number, default: 0 },
    weeklyMessages: { type: [Number], default: [0, 0, 0, 0, 0, 0, 0] },
    weeklyTokens: { type: [Number], default: [0, 0, 0, 0, 0, 0, 0] },
    // 使用普通对象而不是 Map，避免键中包含 "." 报错（如 gpt-3.5-turbo）
    modelUsage: { type: Object, default: {} },
    lastResetDate: { type: String, default: new Date().toDateString() },
  },
  { timestamps: true }
);

const Persona = mongoose.model('Persona', PersonaSchema);
const Config = mongoose.model('Config', ConfigSchema);
const ChatUser = mongoose.model('ChatUser', ChatUserSchema);
const Stats = mongoose.model('Stats', StatsSchema);

// --------- Helpers ---------
function ensureEnvKeyLine(content, key, value) {
  const lines = content.split('\n');
  let found = false;
  const newLines = lines
    .map((l) => {
      if (l.startsWith(`${key}=`)) {
        found = true;
        return `${key}=${value}`;
      }
      return l;
    })
    .filter((l) => l.trim() !== '');
  if (!found) newLines.push(`${key}=${value}`);
  return newLines.join('\n') + '\n';
}

function saveEnvConfig(apiKey, baseURL) {
  let content = '';
  if (fs.existsSync(ENV_FILE)) {
    content = fs.readFileSync(ENV_FILE, 'utf-8');
  }
  content = ensureEnvKeyLine(content, 'OPENAI_API_KEY', apiKey);
  content = ensureEnvKeyLine(content, 'OPENAI_BASE_URL', baseURL);
  fs.writeFileSync(ENV_FILE, content);
  process.env.OPENAI_API_KEY = apiKey;
  process.env.OPENAI_BASE_URL = baseURL;
}

function getEnvConfig() {
  return {
    apiKey: process.env.OPENAI_API_KEY || '',
    baseURL: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
  };
}

function getOpenAIClient() {
  const env = getEnvConfig();
  return new OpenAI({
    apiKey: env.apiKey,
    baseURL: env.baseURL,
  });
}

async function verifyPassword(input, stored) {
  if (!stored) return false;
  if (stored.startsWith('$2')) {
    return bcrypt.compare(input, stored);
  }
  return input === stored;
}

function signToken(username) {
  return jwt.sign({ username }, JWT_SECRET, { expiresIn: '7d' });
}

function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '') || req.cookies.token;
  if (!token) return res.status(401).json({ error: '未登录' });
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (e) {
    return res.status(401).json({ error: '登录已过期' });
  }
}

async function getSingletonModel(Model, defaults = {}) {
  let doc = await Model.findOne();
  if (!doc) {
    doc = new Model(defaults);
    await doc.save();
  }
  return doc;
}

// 智能分段：按标点拆分，删除拆分标点（保留~和省略号）
function splitIntoSegments(text) {
  const splitPunctuation = /([。！？!?，,；;：:、\n])/g;
  const parts = text.split(splitPunctuation).filter((s) => s.trim());
  const segments = [];
  let current = '';

  for (const part of parts) {
    if (/^[。！？!?，,；;：:\n]$/.test(part)) {
      if (current.trim()) {
        segments.push(current.trim());
        current = '';
      }
    } else {
      current += part;
    }
  }
  if (current.trim()) segments.push(current.trim());
  if (segments.length <= 1) return [text.replace(/[。！？!?，,；;：:、]/g, '')];
  return segments;
}

const sessions = new Map(); // userId -> { history, persona }

async function getSession(userId) {
  if (!sessions.has(userId)) {
    const defaultPersona = await Persona.findOne({ isDefault: true }) || (await Persona.findOne()) || {
      id: 'default',
    };
    sessions.set(userId, { history: [], persona: defaultPersona.id });
  }
  return sessions.get(userId);
}

async function checkDailyReset() {
  const stats = await getSingletonModel(Stats);
  const today = new Date().toDateString();
  if (stats.lastResetDate !== today) {
    stats.weeklyMessages.shift();
    stats.weeklyMessages.push(stats.todayMessages);
    stats.weeklyTokens.shift();
    stats.weeklyTokens.push(stats.todayTokens);
    stats.todayMessages = 0;
    stats.todayTokens = 0;
    stats.lastResetDate = today;
    await stats.save();
  }
  return stats;
}

// --------- Express App ---------
const app = express();
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());
app.use(cookieParser());

// 健康检查
app.get('/health', (req, res) => res.json({ ok: true }));

// 登录
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: '缺少用户名或密码' });
  if (username !== ADMIN_USER) return res.status(401).json({ error: '用户名或密码错误' });
  const ok = await verifyPassword(password, ADMIN_PASSWORD);
  if (!ok) return res.status(401).json({ error: '用户名或密码错误' });
  const token = signToken(username);
  res.json({ token });
});

// 配置
app.get('/api/config', authMiddleware, async (req, res) => {
  const cfg = await getSingletonModel(Config);
  const env = getEnvConfig();
  res.json({ ...cfg.toObject(), apiKey: env.apiKey, baseURL: env.baseURL });
});

app.post('/api/config', authMiddleware, async (req, res) => {
  const { apiKey, baseURL, ...rest } = req.body || {};
  const cfg = await getSingletonModel(Config);
  Object.assign(cfg, rest);
  await cfg.save();
  if (apiKey !== undefined && baseURL !== undefined) saveEnvConfig(apiKey, baseURL);
  res.json({ success: true });
});

// 人格
app.get('/api/personas', authMiddleware, async (req, res) => {
  const list = await Persona.find().sort({ order: 1 });
  res.json(list);
});

app.post('/api/personas', authMiddleware, async (req, res) => {
  const { name, prompt, order } = req.body || {};
  const persona = new Persona({
    name,
    prompt,
    order: order || (await Persona.countDocuments()) + 1,
    isDefault: false,
  });
  await persona.save();
  res.json(persona);
});

app.put('/api/personas/:id', authMiddleware, async (req, res) => {
  await Persona.findByIdAndUpdate(req.params.id, req.body);
  res.json({ success: true });
});

app.delete('/api/personas/:id', authMiddleware, async (req, res) => {
  await Persona.findByIdAndDelete(req.params.id);
  res.json({ success: true });
});

app.post('/api/personas/:id/default', authMiddleware, async (req, res) => {
  await Persona.updateMany({}, { isDefault: false });
  await Persona.findByIdAndUpdate(req.params.id, { isDefault: true });
  res.json({ success: true });
});

app.post('/api/personas/swap-order', authMiddleware, async (req, res) => {
  const { id1, id2 } = req.body || {};
  const p1 = await Persona.findById(id1);
  const p2 = await Persona.findById(id2);
  if (p1 && p2) {
    const temp = p1.order;
    p1.order = p2.order;
    p2.order = temp;
    await p1.save();
    await p2.save();
  }
  res.json({ success: true });
});

// 用户与消息
app.get('/api/users', authMiddleware, async (req, res) => {
  const list = await ChatUser.find({}, { messages: 0 }).sort({ lastChatTime: -1 });
  res.json(list);
});

app.get('/api/users/:userId/messages', authMiddleware, async (req, res) => {
  const user = await ChatUser.findOne({ userId: req.params.userId });
  if (!user) return res.json({ user: { userId: req.params.userId, nickname: '未知用户' }, messages: [] });
  res.json({ user: { userId: user.userId, nickname: user.nickname }, messages: user.messages });
});

// 统计
app.get('/api/stats', authMiddleware, async (req, res) => {
  const stats = await checkDailyReset();
  const userRanking = await ChatUser.find({}, { messages: 0 })
    .sort({ messageCount: -1 })
    .limit(10);
  res.json({
    status: currentWs ? 'online' : 'offline',
    totalMessages: stats.totalMessages,
    todayMessages: stats.todayMessages,
    totalTokens: stats.totalTokens,
    todayTokens: stats.todayTokens,
    weeklyMessages: stats.weeklyMessages,
    weeklyTokens: stats.weeklyTokens,
    modelUsage: stats.modelUsage || {},
    activeUsers: await ChatUser.countDocuments(),
    userRanking,
  });
});

const httpServer = app.listen(API_PORT, () => {
  console.log(`📡 API 服务已启动: http://127.0.0.1:${API_PORT}`);
});

// --------- WebSocket (NapCat) ---------
let currentWs = null;

const wss = new WebSocketServer({ port: WS_PORT });
console.log(`🚀 WebSocket 等待 NapCat: ws://127.0.0.1:${WS_PORT}`);

wss.on('connection', (ws) => {
  console.log('✅ NapCat 已连接');
  currentWs = ws;

  ws.on('message', async (data) => {
    try {
      await handleEvent(JSON.parse(data.toString()));
    } catch (err) {
      console.error('处理消息失败:', err);
    }
  });

  ws.on('close', () => {
    console.log('❌ NapCat 断开');
    currentWs = null;
  });
});

// --------- Core Chat Logic ---------
const COMMANDS = {
  '/help': () =>
    `📋 指令列表：
/help - 显示此帮助
/new - 开始新对话
/person <序号> - 切换人格
/person_ls - 查看人格列表`,

  '/new': (userId) => {
    sessions.delete(userId);
    return '✨ 已开始新对话';
  },

  '/person_ls': async () => {
    const list = await Persona.find().sort({ order: 1 });
    const text = list.map((p) => `${p.order}. ${p.name}${p.isDefault ? ' (默认)' : ''}`).join('\n');
    return `🎭 可用人格：\n${text}\n\n使用 /person 序号 切换`;
  },

  '/person': async (userId, args) => {
    const order = parseInt((args || '').trim(), 10);
    if (isNaN(order)) return '用法: /person 序号 (如 /person 1)';
    const persona = await Persona.findOne({ order });
    if (!persona) return `未找到序号 ${order} 的人格，使用 /person_ls 查看列表`;
    const session = await getSession(userId);
    session.persona = persona.id;
    session.history = [];
    return `✅ 已切换到人格「${persona.name}」，对话已重置`;
  },
};

async function handleEvent(event) {
  if (event.post_type !== 'message' || event.message_type !== 'private') return;

  const stats = await checkDailyReset();
  const cfg = await getSingletonModel(Config);

  const userId = String(event.user_id);
  const nickname = event.sender?.nickname || userId;
  const message = (event.raw_message || event.message || '').trim();

  console.log(`📩 [${nickname}]: ${message}`);

  // 初始化用户
  let chatUser = await ChatUser.findOne({ userId });
  if (!chatUser) {
    chatUser = new ChatUser({ userId, nickname });
  } else {
    chatUser.nickname = nickname;
  }

  // 指令
  if (message.startsWith('/')) {
    const [cmd, ...rest] = message.split(' ');
    const handler = COMMANDS[cmd];
    if (handler) {
      const reply =
        typeof handler === 'function'
          ? cmd === '/person'
            ? await handler(userId, rest.join(' '))
            : await handler(userId)
          : handler;
      await sendPrivateMessage(userId, reply);
      return;
    }
  }

  try {
    const session = await getSession(userId);
    session.history.push({ role: 'user', content: message });
    if (session.history.length > cfg.maxHistoryLength * 2) {
      session.history = await compressHistory(session.history, cfg);
    }

    const systemPrompt = await buildSystemPrompt(session.persona, cfg);
    const client = getOpenAIClient();

    const response = await client.chat.completions.create({
      model: cfg.model,
      messages: [{ role: 'system', content: systemPrompt }, ...session.history.slice(-cfg.maxHistoryLength * 2)],
      max_tokens: cfg.maxTokens,
      temperature: cfg.temperature,
    });

    const reply = response.choices[0].message.content;
    const tokensUsed = response.usage?.total_tokens || 0;

    if (cfg.enableStream && reply.length > 30) {
      const segments = splitIntoSegments(reply);
      for (let i = 0; i < segments.length; i++) {
        await sendPrivateMessage(userId, segments[i]);
        if (i < segments.length - 1) await sleep(800 + Math.random() * 400);
      }
    } else {
      await sendPrivateMessage(userId, reply);
    }

    session.history.push({ role: 'assistant', content: reply });

    // 更新统计
    stats.totalMessages += 1;
    stats.todayMessages += 1;
    stats.totalTokens += tokensUsed;
    stats.todayTokens += tokensUsed;
    if (!stats.modelUsage) stats.modelUsage = {};
    stats.modelUsage[cfg.model] = (stats.modelUsage[cfg.model] || 0) + 1;
    await stats.save();

    // 更新用户数据
    const now = new Date();
    chatUser.messageCount += 1;
    chatUser.tokenCount += tokensUsed;
    chatUser.lastChatTime = now;
    chatUser.messages.push(
      { role: 'user', content: message, time: now },
      { role: 'assistant', content: reply, time: now, tokens: tokensUsed }
    );
    if (chatUser.messages.length > 200) {
      chatUser.messages = chatUser.messages.slice(-200);
    }
    await chatUser.save();
  } catch (err) {
    console.error('AI回复失败:', err);
    await sendPrivateMessage(userId, '抱歉，我暂时无法回复，请稍后再试。');
  }
}

async function buildSystemPrompt(personaId, cfg) {
  const persona = await Persona.findById(personaId);
  const personaPrompt = persona?.prompt || '你是一个友好的AI助手。';
  return cfg.globalPrompt ? `${cfg.globalPrompt}\n\n${personaPrompt}` : personaPrompt;
}

async function compressHistory(history, cfg) {
  if (history.length < cfg.summaryThreshold * 2) return history;
  const toCompress = history.slice(0, -cfg.summaryThreshold * 2);
  const toKeep = history.slice(-cfg.summaryThreshold * 2);
  try {
    const client = getOpenAIClient();
    const summaryRes = await client.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: [
        { role: 'system', content: '请用一段简短的文字总结以下对话的要点，保留关键信息：' },
        { role: 'user', content: toCompress.map((m) => `${m.role}: ${m.content}`).join('\n') },
      ],
      max_tokens: 300,
    });
    const summary = summaryRes.choices[0].message.content;
    return [{ role: 'system', content: `[历史对话摘要] ${summary}` }, ...toKeep];
  } catch {
    return toKeep;
  }
}

function sendPrivateMessage(userId, message) {
  if (!currentWs) return;
  currentWs.send(
    JSON.stringify({
      action: 'send_private_msg',
      params: { user_id: parseInt(userId, 10), message },
    })
  );
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// --------- 初始化默认数据 ---------
await getSingletonModel(Config);
if ((await Persona.countDocuments()) === 0) {
  const p = new Persona({ order: 1, name: '默认助手', prompt: '你是一个友好的AI助手。', isDefault: true });
  await p.save();
  console.log('✅ 已创建默认人格');
}
await getSingletonModel(Stats);

console.log('🤖 QQ ChatBot 启动中...');

