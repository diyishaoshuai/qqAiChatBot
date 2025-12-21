# SSH 远程部署指南

本指南介绍如何通过 SSH 从 Windows 本地将 QQ ChatBot 部署到 Linux 云服务器。

## 📋 前置要求

### 本地环境（Windows）
- PowerShell 5.1+ 或 PowerShell Core
- SSH 客户端（Windows 10+ 自带 OpenSSH）
- Git（可选，用于本地开发）

### 服务器环境（Linux）
- Node.js 18+
- pnpm
- Git
- PM2
- MongoDB（本地或远程）

## 🔑 SSH 连接配置

### 方式一：使用 SSH 密钥（推荐）

1. **生成 SSH 密钥对**（如果还没有）：
   ```powershell
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

2. **将公钥复制到服务器**：
   ```powershell
   type $env:USERPROFILE\.ssh\id_rsa.pub | ssh username@server_ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
   ```

3. **测试连接**：
   ```powershell
   ssh -i $env:USERPROFILE\.ssh\id_rsa username@server_ip
   ```

### 方式二：使用密码

如果使用密码登录，脚本会提示输入密码。建议配置 SSH 密钥以实现免密登录。

## 🚀 使用方法

### 基本用法

```powershell
# 交互式运行（会提示输入服务器信息）
.\deploy-ssh.ps1
```

### 使用参数

```powershell
# 指定服务器IP和用户名
.\deploy-ssh.ps1 -ServerIP "192.168.1.100" -Username "root"

# 使用SSH密钥文件
.\deploy-ssh.ps1 -ServerIP "192.168.1.100" -Username "root" -SSHKeyPath "C:\Users\YourName\.ssh\id_rsa"

# 指定自定义端口
.\deploy-ssh.ps1 -ServerIP "192.168.1.100" -Username "root" -Port 2222

# 指定项目目录和分支
.\deploy-ssh.ps1 -ServerIP "192.168.1.100" -ProjectDir "/home/user/qqchatbot" -Branch "main"
```

### 完整参数说明

| 参数 | 说明 | 默认值 | 必填 |
|------|------|--------|------|
| `-ServerIP` | 服务器IP地址 | - | 是 |
| `-Username` | SSH用户名 | `root` | 否 |
| `-Port` | SSH端口 | `22` | 否 |
| `-SSHKeyPath` | SSH私钥文件路径 | - | 否 |
| `-ProjectDir` | 服务器上的项目目录 | `/root/qqchatbot` | 否 |
| `-Branch` | Git分支 | `main` | 否 |

## 📝 部署流程

脚本会自动执行以下步骤：

1. ✅ **检查SSH连接** - 验证能否连接到服务器
2. 📥 **克隆/更新代码** - 从 GitHub 拉取最新代码
3. 📦 **安装依赖** - 安装后端和前端依赖
4. 🔨 **构建前端** - 编译 Vue 前端项目
5. 🛑 **停止旧服务** - 停止现有的 PM2 服务
6. 🚀 **启动新服务** - 使用 PM2 启动后端服务
7. 💾 **保存配置** - 配置 PM2 开机自启

## ⚙️ 首次部署后的配置

### 1. 配置环境变量

首次部署后，需要编辑服务器上的 `.env` 文件：

```powershell
# 使用SSH连接到服务器并编辑文件
ssh username@server_ip "vi /root/qqchatbot/server/.env"
```

或者使用本地编辑器（需要配置 SSH 文件传输）：

```powershell
# 下载 .env 文件到本地
scp username@server_ip:/root/qqchatbot/server/.env .env

# 编辑后上传
scp .env username@server_ip:/root/qqchatbot/server/.env
```

### 2. 配置示例

编辑 `server/.env` 文件，填入以下配置：

```env
# 大模型配置
OPENAI_API_KEY=sk-your-api-key
OPENAI_BASE_URL=https://api.openai.com/v1
# 或使用 DeepSeek
# OPENAI_BASE_URL=https://api.deepseek.com/v1

# MongoDB 连接
MONGODB_URI=mongodb://127.0.0.1:27017/qqchatbot
# 或使用远程 MongoDB
# MONGODB_URI=mongodb://username:password@host:port/database

# JWT 密钥（请修改为随机字符串）
JWT_SECRET=your-random-secret-key-here

# 管理后台账号（请修改）
ADMIN_USER=admin
ADMIN_PASSWORD=your-secure-password

# 端口配置
WS_PORT=3001
API_PORT=3002
```

### 3. 重启服务

配置完成后，重启服务使配置生效：

```powershell
ssh username@server_ip "pm2 restart qqchatbot-server"
```

## 🔧 服务器端依赖安装

如果服务器上还没有安装必要的依赖，可以手动安装：

### 安装 Node.js 18+

```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# CentOS/RHEL
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs
```

### 安装 pnpm

```bash
npm install -g pnpm
```

### 安装 PM2

```bash
npm install -g pm2
```

### 安装 MongoDB（如果需要本地MongoDB）

```bash
# Ubuntu/Debian
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod
```

## 📊 服务管理

### 查看服务状态

```powershell
ssh username@server_ip "pm2 status"
```

### 查看日志

```powershell
# 实时日志
ssh username@server_ip "pm2 logs qqchatbot-server"

# 最近100行日志
ssh username@server_ip "pm2 logs qqchatbot-server --lines 100"
```

### 重启服务

```powershell
ssh username@server_ip "pm2 restart qqchatbot-server"
```

### 停止服务

```powershell
ssh username@server_ip "pm2 stop qqchatbot-server"
```

### 删除服务

```powershell
ssh username@server_ip "pm2 delete qqchatbot-server"
```

## 🔥 防火墙配置

确保服务器防火墙开放以下端口：

```bash
# 使用 firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=3001/tcp
sudo firewall-cmd --permanent --add-port=3002/tcp
sudo firewall-cmd --reload

# 使用 ufw (Ubuntu/Debian)
sudo ufw allow 3001/tcp
sudo ufw allow 3002/tcp
sudo ufw reload
```

同时，在云服务器控制台的安全组中也需要开放这些端口。

## 🌐 配置 NapCat

在 NapCat 中配置反向 WebSocket 连接：

1. 打开 NapCat 网页配置（通常是 http://127.0.0.1:6099）
2. 添加 **反向 WebSocket** 连接
3. 地址填：`ws://服务器IP:3001`

## ❗ 常见问题

### 1. SSH 连接失败

**问题**：无法连接到服务器

**解决方案**：
- 检查服务器IP、端口、用户名是否正确
- 检查服务器是否允许SSH连接
- 检查防火墙是否开放SSH端口（默认22）
- 如果使用密钥，确保密钥文件路径正确

### 2. 权限被拒绝

**问题**：Permission denied

**解决方案**：
- 确保SSH密钥权限正确（Windows通常不需要）
- 检查服务器上的用户权限
- 确保项目目录有写入权限

### 3. 命令未找到

**问题**：node/pnpm/pm2 命令未找到

**解决方案**：
- 确保服务器上已安装 Node.js、pnpm、PM2
- 检查 PATH 环境变量
- 使用完整路径或全局安装

### 4. 部署后服务无法启动

**问题**：PM2 服务启动失败

**解决方案**：
```powershell
# 查看详细错误日志
ssh username@server_ip "pm2 logs qqchatbot-server --err"

# 检查 .env 文件配置是否正确
ssh username@server_ip "cat /root/qqchatbot/server/.env"

# 手动测试启动
ssh username@server_ip "cd /root/qqchatbot/server && node index.js"
```

### 5. MongoDB 连接失败

**问题**：无法连接到 MongoDB

**解决方案**：
- 检查 MongoDB 服务是否运行：`systemctl status mongod`
- 检查 `.env` 中的 `MONGODB_URI` 配置是否正确
- 如果使用远程 MongoDB，检查网络连接和防火墙

## 📚 相关文档

- [本地部署指南](./DEPLOYMENT_GUIDE.md)
- [阿里云部署指南](./ALIYUN_DEPLOYMENT.md)
- [项目 README](../README.md)

