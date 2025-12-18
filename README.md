# QQ ChatBot

基于 NapCat + OpenAI/DeepSeek 的 QQ 聊天机器人，带后台管理界面。

## 功能特性

- 🤖 支持 OpenAI / DeepSeek 大模型
- 🎭 多人格系统，可自定义AI角色
- 💬 连续对话记忆，智能压缩历史
- 📊 后台管理界面（仪表盘、配置、消息记录）
- 📈 数据统计和用户排行榜

## 快速开始

### 1. 安装 NapCat

前往 [NapCat Releases](https://github.com/NapNeko/NapCatQQ/releases) 下载安装，登录你的 QQ 账号。

配置 NapCat：
- 添加 **反向WebSocket** 连接
- 地址填：`ws://127.0.0.1:3001`

### 2. 配置后端

```bash
cd server

# 复制配置文件
copy env.example .env   # Windows
cp env.example .env     # Linux/Mac

# 编辑 .env，填入 API Key
```

### 3. 安装依赖并启动

```bash
# 后端
cd server
pnpm install
pnpm start

# 前端（新终端）
pnpm install
pnpm dev
```

### 4. 访问管理后台

打开 http://localhost:5173

## 聊天指令

| 指令 | 说明 |
|------|------|
| `/help` | 显示帮助 |
| `/new` | 开始新对话 |
| `/person <序号>` | 切换人格 |
| `/person_ls` | 查看人格列表 |

## 项目结构

```
├── server/           # 后端服务
│   ├── index.js      # 主程序
│   └── env.example   # 环境变量模板
├── src/              # 前端 Vue 项目
│   ├── views/        # 页面组件
│   └── router/       # 路由配置
└── README.md
```

## 技术栈

- 前端：Vue 3 + Element Plus + ECharts
- 后端：Node.js + WebSocket + OpenAI SDK
- QQ协议：NapCat (OneBot)
