# 部署指南

本文档提供了 QQ ChatBot 的完整部署指南，包括手动部署和自动化部署两种方式。

## 目录

- [服务器要求](#服务器要求)
- [手动部署](#手动部署)
- [自动化部署](#自动化部署)
- [配置 Nginx](#配置-nginx)
- [常见问题](#常见问题)

---

## 服务器要求

### 最低配置
- **CPU**: 1 核
- **内存**: 1GB
- **存储**: 10GB
- **系统**: Linux (Ubuntu 20.04+, CentOS 7+) 或 Windows Server

### 软件依赖
- Node.js 18+
- pnpm
- MongoDB 5+
- Git
- PM2 (推荐)
- Nginx (可选，用于反向代理)

---

## 手动部署

### Linux 服务器部署

#### 1. 安装依赖

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装 Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 安装 pnpm
npm install -g pnpm

# 安装 PM2
npm install -g pm2

# 安装 MongoDB
# Ubuntu/Debian
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt update
sudo apt install -y mongodb-org

# 启动 MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod

# 安装 Git
sudo apt install -y git
```

#### 2. 克隆项目

```bash
cd /root
git clone git@github.com:diyishaoshuai/qqAiChatBot.git qqchatbot
cd qqchatbot
```

#### 3. 配置环境变量

```bash
cd server
cp .env.example .env
nano .env  # 或使用 vim 编辑
```

填入你的配置：
```env
OPENAI_API_KEY=sk-your-api-key
OPENAI_BASE_URL=https://api.openai.com/v1
MONGODB_URI=mongodb://127.0.0.1:27017/qqchatbot
ADMIN_USER=admin
ADMIN_PASSWORD=your-secure-password
JWT_SECRET=your-random-secret-key
WS_PORT=3001
API_PORT=3002
```

**重要**：生成安全的 JWT_SECRET：
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

#### 4. 安装依赖并构建

```bash
# 安装后端依赖
cd /root/qqchatbot/server
pnpm install --prod

# 安装前端依赖并构建
cd /root/qqchatbot
pnpm install
pnpm build
```

#### 5. 启动服务

```bash
cd /root/qqchatbot/server
pm2 start index.js --name qqchatbot-server
pm2 save
pm2 startup  # 设置开机自启
```

#### 6. 使用部署脚本（推荐）

我们提供了自动化部署脚本，简化上述步骤：

```bash
# 首次部署前，先手动配置 .env 文件
cd /root/qqchatbot/server
cp .env.example .env
nano .env

# 运行部署脚本
cd /root/qqchatbot
chmod +x deploy.sh
./deploy.sh
```

### Windows 服务器部署

#### 1. 安装依赖

1. 下载并安装 [Node.js 18+](https://nodejs.org/)
2. 安装 pnpm：
   ```powershell
   npm install -g pnpm
   ```
3. 安装 PM2（可选）：
   ```powershell
   npm install -g pm2
   npm install -g pm2-windows-startup
   pm2-startup install
   ```
4. 安装 [MongoDB](https://www.mongodb.com/try/download/community)
5. 安装 [Git](https://git-scm.com/download/win)

#### 2. 克隆项目

```powershell
cd C:\
git clone git@github.com:diyishaoshuai/qqAiChatBot.git qqchatbot
cd qqchatbot
```

#### 3. 配置环境变量

```powershell
cd server
copy .env.example .env
notepad .env
```

#### 4. 使用部署脚本

```powershell
cd C:\qqchatbot
.\deploy-windows.ps1
```

---

## 自动化部署

使用 GitHub Actions 实现代码推送后自动部署到服务器。

### 配置步骤

#### 1. 生成 SSH 密钥对

在你的**本地电脑**或**服务器**上生成 SSH 密钥：

```bash
ssh-keygen -t rsa -b 4096 -C "github-actions" -f ~/.ssh/github_actions_key
```

这会生成两个文件：
- `~/.ssh/github_actions_key` (私钥)
- `~/.ssh/github_actions_key.pub` (公钥)

#### 2. 配置服务器

将公钥添加到服务器的 authorized_keys：

```bash
# 在服务器上执行
cat ~/.ssh/github_actions_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### 3. 配置 GitHub Secrets

在 GitHub 仓库中配置以下 Secrets：

1. 进入仓库 → Settings → Secrets and variables → Actions
2. 点击 "New repository secret" 添加以下密钥：

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `SERVER_HOST` | 服务器 IP 地址 | `123.45.67.89` |
| `SERVER_USER` | SSH 用户名 | `root` |
| `SERVER_SSH_KEY` | SSH 私钥内容 | 复制 `~/.ssh/github_actions_key` 的全部内容 |
| `SERVER_PORT` | SSH 端口（可选） | `22` |

**获取私钥内容**：
```bash
cat ~/.ssh/github_actions_key
```

复制输出的全部内容（包括 `-----BEGIN OPENSSH PRIVATE KEY-----` 和 `-----END OPENSSH PRIVATE KEY-----`）。

#### 4. 测试自动部署

配置完成后，每次推送代码到 `main` 分支时，GitHub Actions 会自动：
1. 连接到服务器
2. 拉取最新代码
3. 安装依赖
4. 构建前端
5. 重启后端服务

你也可以手动触发部署：
1. 进入仓库 → Actions
2. 选择 "Deploy to Server"
3. 点击 "Run workflow"

#### 5. 查看部署日志

在 GitHub 仓库的 Actions 标签页可以查看每次部署的详细日志。

---

## 配置 Nginx

使用 Nginx 作为反向代理，提供更好的性能和安全性。

### 安装 Nginx

```bash
sudo apt install -y nginx
```

### 配置文件

创建配置文件 `/etc/nginx/sites-available/qqchatbot`：

```nginx
server {
    listen 80;
    server_name your-domain.com;  # 修改为你的域名或 IP

    # 前端静态文件
    location / {
        root /root/qqchatbot/dist;
        try_files $uri $uri/ /index.html;

        # 缓存静态资源
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # 后端 API
    location /api/ {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket (如果需要从外部访问)
    location /ws/ {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 日志
    access_log /var/log/nginx/qqchatbot_access.log;
    error_log /var/log/nginx/qqchatbot_error.log;
}
```

### 启用配置

```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/qqchatbot /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重载 Nginx
sudo systemctl reload nginx
```

### 配置 HTTPS（推荐）

使用 Let's Encrypt 免费 SSL 证书：

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取证书并自动配置 Nginx
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

---

## 常见问题

### 1. 端口被占用

**问题**：启动服务时提示端口 3001 或 3002 被占用

**解决**：
```bash
# 查看占用端口的进程
sudo lsof -i :3001
sudo lsof -i :3002

# 杀死进程
sudo kill -9 <PID>

# 或修改 .env 中的端口配置
```

### 2. MongoDB 连接失败

**问题**：服务启动时提示无法连接 MongoDB

**解决**：
```bash
# 检查 MongoDB 状态
sudo systemctl status mongod

# 启动 MongoDB
sudo systemctl start mongod

# 查看 MongoDB 日志
sudo tail -f /var/log/mongodb/mongod.log

# 检查连接字符串
# 确保 .env 中的 MONGODB_URI 正确
```

### 3. PM2 服务异常退出

**问题**：PM2 启动的服务频繁重启或退出

**解决**：
```bash
# 查看日志
pm2 logs qqchatbot-server

# 查看详细信息
pm2 show qqchatbot-server

# 增加内存限制
pm2 start index.js --name qqchatbot-server --max-memory-restart 500M

# 重启服务
pm2 restart qqchatbot-server
```

### 4. 前端访问 404

**问题**：访问管理后台显示 404

**解决**：
```bash
# 确保前端已构建
cd /root/qqchatbot
pnpm build

# 检查 dist 目录是否存在
ls -la dist/

# 如果使用 Nginx，检查配置中的 root 路径是否正确
sudo nginx -t
```

### 5. API 请求跨域错误

**问题**：前端请求后端 API 时出现 CORS 错误

**解决**：
- 检查前端配置文件中的 API 地址
- 确保后端 CORS 配置正确（已在 `server/index.js:224` 配置）
- 如果使用 Nginx，确保代理配置正确

### 6. GitHub Actions 部署失败

**问题**：自动部署失败

**解决**：
1. 检查 GitHub Secrets 是否配置正确
2. 确保 SSH 密钥有权限访问服务器
3. 检查服务器上的项目路径是否正确
4. 查看 Actions 日志获取详细错误信息

### 7. NapCat 无法连接

**问题**：NapCat 无法连接到 WebSocket 服务

**解决**：
```bash
# 检查 WebSocket 服务是否运行
pm2 logs qqchatbot-server | grep WebSocket

# 检查防火墙
sudo ufw status
sudo ufw allow 3001/tcp

# 确保 NapCat 配置的地址正确
# 如果在同一服务器: ws://127.0.0.1:3001
# 如果在不同服务器: ws://your-server-ip:3001
```

### 8. 内存不足

**问题**：服务器内存不足导致服务崩溃

**解决**：
```bash
# 配置 swap 空间
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 永久启用
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 限制 Node.js 内存使用
pm2 start index.js --name qqchatbot-server --node-args="--max-old-space-size=512"
```

---

## 维护命令

### PM2 常用命令

```bash
# 查看所有服务
pm2 list

# 查看日志
pm2 logs qqchatbot-server

# 重启服务
pm2 restart qqchatbot-server

# 停止服务
pm2 stop qqchatbot-server

# 删除服务
pm2 delete qqchatbot-server

# 监控
pm2 monit

# 保存配置
pm2 save

# 清空日志
pm2 flush
```

### MongoDB 常用命令

```bash
# 连接 MongoDB
mongosh

# 查看数据库
show dbs

# 使用数据库
use qqchatbot

# 查看集合
show collections

# 查询数据
db.chatusers.find().limit(10)
db.stats.findOne()

# 备份数据库
mongodump --db qqchatbot --out /backup/mongodb/

# 恢复数据库
mongorestore --db qqchatbot /backup/mongodb/qqchatbot/
```

### Nginx 常用命令

```bash
# 测试配置
sudo nginx -t

# 重载配置
sudo systemctl reload nginx

# 重启 Nginx
sudo systemctl restart nginx

# 查看状态
sudo systemctl status nginx

# 查看日志
sudo tail -f /var/log/nginx/qqchatbot_access.log
sudo tail -f /var/log/nginx/qqchatbot_error.log
```

---

## 安全建议

1. **修改默认密码**：务必修改 `.env` 中的 `ADMIN_PASSWORD`
2. **使用强密钥**：生成随机的 `JWT_SECRET`
3. **配置防火墙**：只开放必要的端口（80, 443, 22）
4. **使用 HTTPS**：配置 SSL 证书
5. **定期更新**：保持系统和依赖包更新
6. **备份数据**：定期备份 MongoDB 数据
7. **监控日志**：定期检查服务日志
8. **限制访问**：使用 Nginx 限制 API 访问频率

---

## 性能优化

1. **启用 Gzip 压缩**（Nginx）
2. **配置静态资源缓存**
3. **使用 CDN**（如果有域名）
4. **优化 MongoDB 索引**
5. **限制历史消息数量**（已在代码中实现）
6. **使用 PM2 集群模式**（如果需要）

---

## 联系支持

如果遇到问题，可以：
1. 查看项目 [GitHub Issues](https://github.com/diyishaoshuai/qqAiChatBot/issues)
2. 提交新的 Issue
3. 查看项目文档

---

**祝部署顺利！** 🚀
