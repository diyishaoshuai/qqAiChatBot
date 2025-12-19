# QQ AI ChatBot

基于 NapCat + OpenAI/DeepSeek 的 QQ 智能聊天机器人，带 Web 后台管理界面。

## ✨ 功能特性

- 🤖 **多模型支持** - 支持 OpenAI (GPT-3.5/4) 和 DeepSeek 大模型
- 🎭 **多人格系统** - 可创建多个 AI 人格，用户通过指令切换
- 💬 **连续对话** - 支持上下文记忆，智能压缩长对话节省 Token
- 📊 **数据统计** - 消息数、Token 消耗、用户排行榜等
- 🎯 **分段发送** - 长消息智能拆分，模拟真人打字效果
- 🌐 **Web 管理后台** - 可视化配置、查看聊天记录
- 🔐 **登录认证** - 后台需登录后使用
- 🗄 **MongoDB 存储** - 配置/人格/用户/消息均存储在 MongoDB

## 📸 截图

### 仪表盘
- 机器人状态、今日/总消息数、Token 消耗统计
- 近 7 天消息量和 Token 消耗趋势图
- 用户聊天排行榜

### 配置管理
- 模型提供商和模型选择
- API Key 和 Base URL 配置
- 全局约束提示词设置
- 对话优化参数调整

### 人格管理
- 创建/编辑/删除人格
- 调整人格序号
- 设置默认人格

### 消息记录
- 用户列表（昵称、QQ号、消息数、Token消耗）
- ChatGPT 风格的对话详情页

## 🚀 快速开始

### 环境要求

- Node.js 18+
- pnpm
- NapCat (QQ 协议端)
- MongoDB 5+（本地或云端）

### 1. 安装 NapCat

前往 [NapCat Releases](https://github.com/NapNeko/NapCatQQ/releases) 下载安装。

启动 NapCat 并登录 QQ 后，配置反向 WebSocket：
- 打开 NapCat 网页配置（通常是 http://127.0.0.1:6099）
- 添加 **反向 WebSocket** 连接
- 地址填：`ws://127.0.0.1:3001`

### 2. 克隆项目

```bash
git clone git@github.com:diyishaoshuai/qqAiChatBot.git
cd qqAiChatBot
```

### 3. 配置后端

```bash
cd server

# 复制环境变量模板
copy env.example .env   # Windows
cp env.example .env     # Linux/Mac
```

编辑 `.env` 文件，填入你的 API Key、Mongo 连接、管理端账号：

```env
# OpenAI
OPENAI_API_KEY=sk-your-api-key
OPENAI_BASE_URL=https://api.openai.com/v1

# MongoDB
MONGODB_URI=mongodb://127.0.0.1:27017/qqchatbot

# 管理后台账号（请修改）
ADMIN_USER=admin
ADMIN_PASSWORD=admin123

# JWT 密钥（请修改）
JWT_SECRET=please-change-me

# 或 DeepSeek
OPENAI_API_KEY=sk-your-deepseek-key
OPENAI_BASE_URL=https://api.deepseek.com/v1
```

### 4. 安装依赖

```bash
# 后端依赖
cd server
pnpm install

# 前端依赖（回到项目根目录）
cd ..
pnpm install
```

### 5. 启动服务

```bash
# 终端 1 - 启动后端
cd server
pnpm start

# 终端 2 - 启动前端
pnpm dev
```

### 6. 访问

- 管理后台：http://localhost:5173
- 私聊你的 QQ 机器人即可开始对话
- 首次登录账号：`admin / admin123`（请在 `.env` 修改）

## 💬 聊天指令

| 指令 | 说明 | 示例 |
|------|------|------|
| `/help` | 显示帮助列表 | `/help` |
| `/new` | 清空对话，开始新会话 | `/new` |
| `/person <序号>` | 切换到指定人格 | `/person 2` |
| `/person_ls` | 查看可用人格列表 | `/person_ls` |

## 📁 项目结构

```
qqAiChatBot/
├── server/                 # 后端服务
│   ├── index.js            # 主程序（WebSocket + HTTP API）
│   ├── env.example         # 环境变量模板
│   ├── package.json
│   └── *.json              # 运行时数据文件（已 gitignore）
├── src/                    # 前端 Vue 项目
│   ├── views/
│   │   ├── Dashboard.vue   # 仪表盘
│   │   ├── Config.vue      # 配置管理
│   │   ├── Personas.vue    # 人格管理
│   │   ├── Records.vue     # 用户列表
│   │   └── ChatDetail.vue  # 聊天详情
│   ├── router/index.ts     # 路由配置
│   ├── App.vue             # 主布局
│   └── main.ts             # 入口文件
├── .gitignore
├── README.md
└── package.json
```

## 🔧 配置说明

### 环境变量 (.env)

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `OPENAI_API_KEY` | API 密钥 | - |
| `OPENAI_BASE_URL` | API 地址 | `https://api.openai.com/v1` |
| `MONGODB_URI` | Mongo 连接串 | `mongodb://127.0.0.1:27017/qqchatbot` |
| `ADMIN_USER` | 后台用户名 | `admin` |
| `ADMIN_PASSWORD` | 后台密码 | `admin123` |
| `JWT_SECRET` | JWT 密钥 | `please-change-me` |
| `WS_PORT` | WebSocket 端口 | `3001` |
| `API_PORT` | HTTP API 端口 | `3002` |

### 后台配置

在管理后台可以配置：
- **模型提供商**：OpenAI / DeepSeek
- **模型**：GPT-3.5-Turbo / GPT-4 / DeepSeek Chat 等
- **最大 Token**：单次回复的最大 Token 数
- **温度**：回复的随机性（0-2）
- **分段发送**：长消息是否拆分发送
- **全局约束提示词**：约束所有人格的基础规则
- **历史轮数 / 压缩阈值**：对话记忆优化参数

## 🛠 技术栈

**前端**
- Vue 3 + TypeScript
- Element Plus (UI 组件库)
- ECharts (图表)
- Vue Router + Pinia

**后端**
- Node.js
- WebSocket (ws)
- OpenAI SDK

**QQ 协议**
- NapCat (OneBot 11 协议)

## 📝 更新日志

### v1.1.0
- 数据改为 MongoDB 持久化
- 新增后台登录认证
- 配置/密钥通过 `.env` 管理

### v1.0.0
- 初始版本
- 支持 OpenAI / DeepSeek 模型
- 多人格系统
- 连续对话 + 历史压缩
- Web 管理后台
- 分段发送功能

## 📄 License

MIT
