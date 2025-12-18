import WebSocket, { WebSocketServer } from 'ws';
import OpenAI from 'openai';
import dotenv from 'dotenv';
import http from 'http';
import fs from 'fs';

dotenv.config();

// 文件路径
const CONFIG_FILE = './config.json';
const PERSONAS_FILE = './personas.json';
const STATS_FILE = './stats.json';
const USERS_FILE = './users.json';
const ENV_FILE = './.env';

// 默认配置
let config = {
  provider: 'openai',
  model: 'gpt-3.5-turbo',
  maxTokens: 1000,
  temperature: 0.7,
  maxHistoryLength: 20,
  summaryThreshold: 10,
  globalPrompt: '你必须遵守以下规则：1. 使用中文回复 2. 回复简洁明了',
  enableStream: true
};

// 从.env读取API配置
function getEnvConfig() {
  return {
    apiKey: process.env.OPENAI_API_KEY || '',
    baseURL: process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1'
  };
}

// 写入.env文件
function saveEnvConfig(apiKey, baseURL) {
  let envContent = '';
  if (fs.existsSync(ENV_FILE)) {
    envContent = fs.readFileSync(ENV_FILE, 'utf-8');
  }
  
  // 更新或添加配置
  const lines = envContent.split('\n');
  const newLines = [];
  let hasApiKey = false, hasBaseURL = false;
  
  for (const line of lines) {
    if (line.startsWith('OPENAI_API_KEY=')) {
      newLines.push(`OPENAI_API_KEY=${apiKey}`);
      hasApiKey = true;
    } else if (line.startsWith('OPENAI_BASE_URL=')) {
      newLines.push(`OPENAI_BASE_URL=${baseURL}`);
      hasBaseURL = true;
    } else {
      newLines.push(line);
    }
  }
  
  if (!hasApiKey) newLines.push(`OPENAI_API_KEY=${apiKey}`);
  if (!hasBaseURL) newLines.push(`OPENAI_BASE_URL=${baseURL}`);
  
  fs.writeFileSync(ENV_FILE, newLines.filter(l => l.trim()).join('\n') + '\n');
  
  // 更新环境变量
  process.env.OPENAI_API_KEY = apiKey;
  process.env.OPENAI_BASE_URL = baseURL;
}

// 默认人格
let personas = [
  { id: 'default', order: 1, name: '默认助手', prompt: '你是一个友好的AI助手。', isDefault: true }
];

// 用户数据
let users = {};

// 用户会话
const sessions = new Map();

// 统计数据
let stats = {
  status: 'offline',
  totalMessages: 0,
  todayMessages: 0,
  activeUsers: new Set(),
  totalTokens: 0,
  todayTokens: 0,
  weeklyMessages: [0, 0, 0, 0, 0, 0, 0],
  weeklyTokens: [0, 0, 0, 0, 0, 0, 0],
  modelUsage: {},
  lastResetDate: new Date().toDateString()
};

// 加载数据
function loadData() {
  try {
    if (fs.existsSync(CONFIG_FILE)) config = { ...config, ...JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf-8')) };
    if (fs.existsSync(PERSONAS_FILE)) personas = JSON.parse(fs.readFileSync(PERSONAS_FILE, 'utf-8'));
    if (fs.existsSync(USERS_FILE)) users = JSON.parse(fs.readFileSync(USERS_FILE, 'utf-8'));
    if (fs.existsSync(STATS_FILE)) {
      const saved = JSON.parse(fs.readFileSync(STATS_FILE, 'utf-8'));
      stats = { ...stats, ...saved, activeUsers: new Set(saved.activeUsers || []) };
    }
  } catch (e) {
    console.error('加载数据失败:', e.message);
  }
}

function saveConfig() { fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2)); }
function savePersonas() { fs.writeFileSync(PERSONAS_FILE, JSON.stringify(personas, null, 2)); }
function saveUsers() { fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2)); }
function saveStats() {
  const toSave = { ...stats, activeUsers: Array.from(stats.activeUsers) };
  fs.writeFileSync(STATS_FILE, JSON.stringify(toSave, null, 2));
}

// 每日重置
function checkDailyReset() {
  const today = new Date().toDateString();
  if (stats.lastResetDate !== today) {
    stats.weeklyMessages.shift();
    stats.weeklyMessages.push(stats.todayMessages);
    stats.weeklyTokens.shift();
    stats.weeklyTokens.push(stats.todayTokens);
    stats.todayMessages = 0;
    stats.todayTokens = 0;
    stats.activeUsers.clear();
    stats.lastResetDate = today;
    saveStats();
  }
}

loadData();

function getOpenAIClient() {
  const env = getEnvConfig();
  return new OpenAI({
    apiKey: env.apiKey,
    baseURL: env.baseURL,
  });
}

const WS_PORT = parseInt(process.env.WS_PORT || '3001');
const API_PORT = parseInt(process.env.API_PORT || '3002');

let currentWs = null;

// 指令处理
const COMMANDS = {
  '/help': () => `📋 指令列表：
/help - 显示此帮助
/new - 开始新对话
/person <序号> - 切换人格
/person_ls - 查看人格列表`,

  '/new': (userId) => {
    sessions.delete(userId);
    return '✨ 已开始新对话';
  },

  '/person_ls': () => {
    const sorted = [...personas].sort((a, b) => a.order - b.order);
    const list = sorted.map(p => `${p.order}. ${p.name}${p.isDefault ? ' (默认)' : ''}`).join('\n');
    return `🎭 可用人格：\n${list}\n\n使用 /person 序号 切换`;
  },

  '/person': (userId, args) => {
    const order = parseInt(args.trim());
    if (isNaN(order)) return '用法: /person 序号 (如 /person 1)';
    const persona = personas.find(p => p.order === order);
    if (!persona) return `未找到序号 ${order} 的人格，使用 /person_ls 查看列表`;
    const session = getSession(userId);
    session.persona = persona.id;
    session.history = [];
    return `✅ 已切换到人格「${persona.name}」，对话已重置`;
  }
};

function getSession(userId) {
  if (!sessions.has(userId)) {
    const defaultPersona = personas.find(p => p.isDefault) || personas[0];
    sessions.set(userId, { history: [], persona: defaultPersona.id });
  }
  return sessions.get(userId);
}

function getPersonaPrompt(personaId) {
  const persona = personas.find(p => p.id === personaId);
  return persona?.prompt || personas[0].prompt;
}

function getFullSystemPrompt(personaId) {
  const personaPrompt = getPersonaPrompt(personaId);
  return config.globalPrompt ? `${config.globalPrompt}\n\n${personaPrompt}` : personaPrompt;
}

// 压缩历史对话
async function compressHistory(history) {
  if (history.length < config.summaryThreshold * 2) return history;
  
  const toCompress = history.slice(0, -config.summaryThreshold * 2);
  const toKeep = history.slice(-config.summaryThreshold * 2);
  
  try {
    const client = getOpenAIClient();
    const summaryRes = await client.chat.completions.create({
      model: 'gpt-3.5-turbo',
      messages: [
        { role: 'system', content: '请用一段简短的文字总结以下对话的要点，保留关键信息：' },
        { role: 'user', content: toCompress.map(m => `${m.role}: ${m.content}`).join('\n') }
      ],
      max_tokens: 300
    });
    
    const summary = summaryRes.choices[0].message.content;
    return [{ role: 'system', content: `[历史对话摘要] ${summary}` }, ...toKeep];
  } catch {
    return toKeep;
  }
}

// 获取用户排行
function getUserRanking() {
  return Object.entries(users)
    .map(([userId, data]) => ({
      userId,
      nickname: data.nickname,
      messageCount: data.messageCount,
      tokenCount: data.tokenCount
    }))
    .sort((a, b) => b.messageCount - a.messageCount)
    .slice(0, 10);
}

// HTTP API
const apiServer = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.writeHead(200); res.end(); return; }

  const url = req.url;
  const method = req.method;

  // Stats
  if (url === '/api/stats' && method === 'GET') {
    checkDailyReset();
    res.end(JSON.stringify({
      ...stats,
      activeUsers: stats.activeUsers.size,
      userRanking: getUserRanking()
    }));
  }
  // Config (包含从.env读取apiKey和baseURL)
  else if (url === '/api/config' && method === 'GET') {
    const env = getEnvConfig();
    res.end(JSON.stringify({ ...config, apiKey: env.apiKey, baseURL: env.baseURL }));
  }
  else if (url === '/api/config' && method === 'POST') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      const data = JSON.parse(body);
      // 分离apiKey和baseURL，写入.env
      const { apiKey, baseURL, ...rest } = data;
      if (apiKey !== undefined && baseURL !== undefined) {
        saveEnvConfig(apiKey, baseURL);
      }
      config = { ...config, ...rest };
      saveConfig();
      res.end(JSON.stringify({ success: true }));
    });
  }
  // Personas
  else if (url === '/api/personas' && method === 'GET') {
    res.end(JSON.stringify(personas));
  }
  else if (url === '/api/personas' && method === 'POST') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      const data = JSON.parse(body);
      const newPersona = { id: Date.now().toString(), order: data.order || personas.length + 1, name: data.name, prompt: data.prompt, isDefault: false };
      personas.push(newPersona);
      savePersonas();
      res.end(JSON.stringify(newPersona));
    });
  }
  else if (url === '/api/personas/swap-order' && method === 'POST') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      const { id1, id2 } = JSON.parse(body);
      const p1 = personas.find(p => p.id === id1);
      const p2 = personas.find(p => p.id === id2);
      if (p1 && p2) {
        const temp = p1.order;
        p1.order = p2.order;
        p2.order = temp;
        savePersonas();
      }
      res.end(JSON.stringify({ success: true }));
    });
  }
  else if (url.match(/^\/api\/personas\/\w+$/) && method === 'PUT') {
    const id = url.split('/').pop();
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      const data = JSON.parse(body);
      const idx = personas.findIndex(p => p.id === id);
      if (idx >= 0) {
        personas[idx] = { ...personas[idx], ...data };
        savePersonas();
      }
      res.end(JSON.stringify({ success: true }));
    });
  }
  else if (url.match(/^\/api\/personas\/\w+$/) && method === 'DELETE') {
    const id = url.split('/').pop();
    personas = personas.filter(p => p.id !== id);
    savePersonas();
    res.end(JSON.stringify({ success: true }));
  }
  else if (url.match(/^\/api\/personas\/\w+\/default$/) && method === 'POST') {
    const id = url.split('/')[3];
    personas.forEach(p => p.isDefault = p.id === id);
    savePersonas();
    res.end(JSON.stringify({ success: true }));
  }
  // Users
  else if (url === '/api/users' && method === 'GET') {
    const userList = Object.entries(users).map(([userId, data]) => ({
      userId,
      nickname: data.nickname,
      messageCount: data.messageCount,
      tokenCount: data.tokenCount,
      lastChatTime: data.lastChatTime
    })).sort((a, b) => new Date(b.lastChatTime).getTime() - new Date(a.lastChatTime).getTime());
    res.end(JSON.stringify(userList));
  }
  else if (url.match(/^\/api\/users\/\d+\/messages$/) && method === 'GET') {
    const userId = url.split('/')[3];
    const userData = users[userId];
    if (userData) {
      res.end(JSON.stringify({
        user: { userId, nickname: userData.nickname },
        messages: userData.messages || []
      }));
    } else {
      res.end(JSON.stringify({ user: { userId, nickname: '未知用户' }, messages: [] }));
    }
  }
  else {
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

apiServer.listen(API_PORT, () => console.log(`📡 API服务: http://127.0.0.1:${API_PORT}`));

// WebSocket
function startServer() {
  const wss = new WebSocketServer({ port: WS_PORT });
  console.log(`🚀 WebSocket: ws://127.0.0.1:${WS_PORT}`);

  wss.on('connection', (ws) => {
    console.log('✅ NapCat 已连接');
    currentWs = ws;
    stats.status = 'online';

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
      stats.status = 'offline';
    });
  });
}

async function handleEvent(event) {
  if (event.post_type !== 'message' || event.message_type !== 'private') return;

  checkDailyReset();
  
  const userId = String(event.user_id);
  const nickname = event.sender?.nickname || userId;
  const message = (event.raw_message || event.message).trim();
  
  console.log(`📩 [${nickname}]: ${message}`);

  // 初始化用户数据
  if (!users[userId]) {
    users[userId] = { nickname, messageCount: 0, tokenCount: 0, lastChatTime: '', messages: [] };
  }
  users[userId].nickname = nickname;

  // 处理指令
  if (message.startsWith('/')) {
    const [cmd, ...args] = message.split(' ');
    const handler = COMMANDS[cmd];
    if (handler) {
      const reply = typeof handler === 'function' 
        ? (cmd === '/person' ? handler(userId, args.join(' ')) : handler(userId))
        : handler;
      await sendPrivateMessage(userId, reply);
      return;
    }
  }

  try {
    const session = getSession(userId);
    session.history.push({ role: 'user', content: message });
    
    // 压缩历史
    if (session.history.length > config.maxHistoryLength * 2) {
      session.history = await compressHistory(session.history);
    }

    const systemPrompt = getFullSystemPrompt(session.persona);
    const now = new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    
    let reply = '';
    let tokensUsed = 0;

    // 先获取完整回复
    const client = getOpenAIClient();
    const response = await client.chat.completions.create({
      model: config.model,
      messages: [
        { role: 'system', content: systemPrompt },
        ...session.history.slice(-config.maxHistoryLength * 2)
      ],
      max_tokens: config.maxTokens,
      temperature: config.temperature,
    });

    reply = response.choices[0].message.content;
    tokensUsed = response.usage?.total_tokens || 0;

    if (config.enableStream && reply.length > 30) {
      // 分段发送：按标点符号拆分成多条消息
      const segments = splitIntoSegments(reply);
      for (let i = 0; i < segments.length; i++) {
        await sendPrivateMessage(userId, segments[i]);
        if (i < segments.length - 1) {
          await sleep(800 + Math.random() * 400); // 随机延迟800-1200ms
        }
      }
    } else {
      // 整条发送
      await sendPrivateMessage(userId, reply);
    }
    
    session.history.push({ role: 'assistant', content: reply });
    console.log(`📤 [${nickname}]: ${reply.slice(0, 50)}...`);

    // 更新统计
    stats.totalMessages++;
    stats.todayMessages++;
    stats.totalTokens += tokensUsed;
    stats.todayTokens += tokensUsed;
    stats.activeUsers.add(userId);
    stats.modelUsage[config.model] = (stats.modelUsage[config.model] || 0) + 1;
    
    // 更新用户数据
    users[userId].messageCount++;
    users[userId].tokenCount += tokensUsed;
    users[userId].lastChatTime = new Date().toLocaleString('zh-CN');
    users[userId].messages.push(
      { id: Date.now(), role: 'user', content: message, time: now },
      { id: Date.now() + 1, role: 'assistant', content: reply, time: now, tokens: tokensUsed }
    );
    // 只保留最近200条消息
    if (users[userId].messages.length > 200) {
      users[userId].messages = users[userId].messages.slice(-200);
    }
    
    saveUsers();
    saveStats();
  } catch (err) {
    console.error('AI回复失败:', err);
    await sendPrivateMessage(userId, '抱歉，我暂时无法回复，请稍后再试。');
  }
}

function sendPrivateMessage(userId, message) {
  if (!currentWs) return;
  currentWs.send(JSON.stringify({
    action: 'send_private_msg',
    params: { user_id: parseInt(userId), message }
  }));
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// 智能分段：按标点符号拆分，删除标点（保留~和省略号）
function splitIntoSegments(text) {
  // 用于拆分的标点
  const splitPunctuation = /([。！？!?，,；;：:、\n])/g;
  
  const parts = text.split(splitPunctuation).filter(s => s.trim());
  const segments = [];
  let current = '';
  
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i].trim();
    if (!part) continue;
    
    // 如果是标点符号（用于拆分的）
    if (/^[。！？!?，,；;：:、\n]$/.test(part)) {
      // 删除该标点，但如果current有内容就作为一段
      if (current.trim()) {
        segments.push(current.trim());
        current = '';
      }
    } else {
      current += part;
    }
  }
  if (current.trim()) segments.push(current.trim());
  
  // 如果只有一段或原文很短，直接返回
  if (segments.length <= 1) return [text.replace(/[。！？!?，,；;：:、]/g, '')];
  
  return segments;
}

startServer();
console.log(`🤖 QQ ChatBot 启动中...`);
