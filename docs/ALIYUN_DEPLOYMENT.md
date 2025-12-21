# 阿里云 Linux 部署指南

本文档专门针对 **Alibaba Cloud Linux 3.2104 LTS 64位** 系统的部署指南。

## 📋 目录

- [服务器要求](#服务器要求)
- [快速部署](#快速部署)
- [手动部署](#手动部署)
- [配置安全组](#配置安全组)
- [配置 Nginx](#配置-nginx)
- [常见问题](#常见问题)

---

## 服务器要求

### 推荐配置
- **CPU**: 2 核
- **内存**: 2GB
- **存储**: 20GB
- **系统**: Alibaba Cloud Linux 3.2104 LTS 64位
- **带宽**: 1Mbps+

### 最低配置
- **CPU**: 1 核
- **内存**: 1GB
- **存储**: 10GB

---

## 快速部署

### 第一步：连接服务器

```bash
ssh root@your-server-ip
```

### 第二步：下载部署脚本

```bash
# 下载项目
cd /root
git clone https://github.com/diyishaoshuai/qqAiChatBot.git qqchatbot
cd qqchatbot
```

### 第三步：配置环境变量

```bash
cd /root/qqchatbot/server
cp .env.example .env
vi .env
```

**必填配置项**：

```env
# OpenAI API 配置
OPENAI_API_KEY=sk-your-api-key-here
OPENAI_BASE_URL=https://api.openai.com/v1

# MongoDB 配置（默认即可）
MONGODB_URI=mongodb://127.0.0.1:27017/qqchatbot

# 管理后台账号（务必修改）
ADMIN_USER=admin
ADMIN_PASSWORD=your-secure-password

# JWT 密钥（务必修改）
JWT_SECRET=your-random-secret-key

# 端口配置（默认即可）
WS_PORT=3001
API_PORT=3002
```

**生成安全的 JWT_SECRET**：
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### 第四步：运行部署脚本

```bash
cd /root/qqchatbot
chmod +x deploy-aliyun.sh
./deploy-aliyun.sh
```

脚本会自动完成：
- ✅ 安装 Node.js、pnpm、PM2、Git、MongoDB
- ✅ 克隆/更新代码
- ✅ 安装依赖
- ✅ 构建前端
- ✅ 启动服务
- ✅ 配置防火墙
- ✅ 设置开机自启

### 第五步：配置阿里云安全组

**重要**：必须在阿里云控制台开放以下端口，否则无法访问！

1. 登录 [阿里云控制台](https://ecs.console.aliyun.com/)
2. 进入 **云服务器 ECS** → **实例**
3. 找到你的服务器，点击 **更多** → **网络和安全组** → **安全组配置**
4. 点击 **配置规则** → **添加安全组规则**

添加以下规则：

| 端口范围 | 授权对象 | 说明 |
|---------|---------|------|
| 3001/3001 | 0.0.0.0/0 | WebSocket 服务 |
| 3002/3002 | 0.0.0.0/0 | API 服务 |
| 80/80 | 0.0.0.0/0 | HTTP（如果使用 Nginx） |
| 443/443 | 0.0.0.0/0 | HTTPS（如果使用 Nginx） |

### 第六步：配置 NapCat

在 NapCat 的反向 WebSocket 配置中填入：

```
ws://your-server-ip:3001
```

将 `your-server-ip` 替换为你的阿里云服务器公网 IP。

---

## 手动部署

如果自动脚本遇到问题，可以按以下步骤手动部署。

### 1. 安装 Node.js 18

```bash
# 添加 NodeSource 仓库
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -

# 安装 Node.js
yum install -y nodejs

# 验证安装
node -v
npm -v
```

### 2. 安装 pnpm

```bash
npm install -g pnpm
pnpm -v
```

### 3. 安装 PM2

```bash
npm install -g pm2
pm2 -v
```

### 4. 安装 Git

```bash
yum install -y git
git --version
```

### 5. 安装 MongoDB

```bash
# 创建 MongoDB yum 源
cat > /etc/yum.repos.d/mongodb-org-6.0.repo <<EOF
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF

# 安装 MongoDB
yum install -y mongodb-org

# 启动 MongoDB
systemctl start mongod
systemctl enable mongod

# 检查状态
systemctl status mongod
```

### 6. 克隆项目

```bash
cd /root
git clone https://github.com/diyishaoshuai/qqAiChatBot.git qqchatbot
cd qqchatbot
```

### 7. 配置环境变量

```bash
cd /root/qqchatbot/server
cp .env.example .env
vi .env
```

### 8. 安装依赖

```bash
# 安装后端依赖
cd /root/qqchatbot/server
pnpm install --prod

# 安装前端依赖
cd /root/qqchatbot
pnpm install
```

### 9. 构建前端

```bash
cd /root/qqchatbot
pnpm build
```

### 10. 启动服务

```bash
cd /root/qqchatbot/server
pm2 start index.js --name qqchatbot-server
pm2 save
pm2 startup
```

### 11. 配置防火墙

```bash
# 开放端口
firewall-cmd --permanent --add-port=3001/tcp
firewall-cmd --permanent --add-port=3002/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload

# 查看已开放端口
firewall-cmd --list-ports
```

---

## 配置安全组

### 方法一：通过阿里云控制台（推荐）

1. 登录 [阿里云控制台](https://ecs.console.aliyun.com/)
2. 左侧菜单选择 **实例与镜像** → **实例**
3. 找到你的 ECS 实例
4. 点击实例 ID 进入详情页
5. 点击 **安全组** 标签页
6. 点击安全组 ID
7. 点击 **入方向** → **手动添加**

添加以下规则：

**规则 1：WebSocket 服务**
- 协议类型：自定义 TCP
- 端口范围：3001/3001
- 授权对象：0.0.0.0/0
- 描述：QQ ChatBot WebSocket

**规则 2：API 服务**
- 协议类型：自定义 TCP
- 端口范围：3002/3002
- 授权对象：0.0.0.0/0
- 描述：QQ ChatBot API

**规则 3：HTTP（可选）**
- 协议类型：HTTP(80)
- 端口范围：80/80
- 授权对象：0.0.0.0/0
- 描述：HTTP

**规则 4：HTTPS（可选）**
- 协议类型：HTTPS(443)
- 端口范围：443/443
- 授权对象：0.0.0.0/0
- 描述：HTTPS

### 方法二：通过阿里云 CLI

```bash
# 安装阿里云 CLI
wget https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz
tar -xzf aliyun-cli-linux-latest-amd64.tgz
mv aliyun /usr/local/bin/

# 配置凭证
aliyun configure

# 添加安全组规则
aliyun ecs AuthorizeSecurityGroup \
  --SecurityGroupId sg-xxxxx \
  --IpProtocol tcp \
  --PortRange 3001/3001 \
  --SourceCidrIp 0.0.0.0/0
```

---

## 配置 Nginx

### 1. 安装 Nginx

```bash
yum install -y nginx
systemctl start nginx
systemctl enable nginx
```

### 2. 创建配置文件

```bash
vi /etc/nginx/conf.d/qqchatbot.conf
```

添加以下内容：

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

    # WebSocket（如果需要从外部访问）
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

### 3. 测试并重载配置

```bash
# 测试配置
nginx -t

# 重载配置
systemctl reload nginx
```

### 4. 配置 HTTPS（推荐）

```bash
# 安装 Certbot
yum install -y certbot python3-certbot-nginx

# 获取证书
certbot --nginx -d your-domain.com

# 自动续期测试
certbot renew --dry-run
```

---

## 常见问题

### 1. yum 命令找不到包

**问题**：执行 `yum install` 时提示找不到包

**解决**：
```bash
# 更新 yum 缓存
yum clean all
yum makecache

# 如果还是不行，尝试使用 dnf
dnf install -y nodejs
```

### 2. MongoDB 启动失败

**问题**：MongoDB 无法启动

**解决**：
```bash
# 查看日志
journalctl -u mongod -n 50

# 检查磁盘空间
df -h

# 检查 SELinux
getenforce
# 如果是 Enforcing，临时关闭
setenforce 0

# 永久关闭 SELinux（不推荐，仅用于测试）
vi /etc/selinux/config
# 将 SELINUX=enforcing 改为 SELINUX=disabled
```

### 3. 端口无法访问

**问题**：服务启动了但无法从外网访问

**解决**：
```bash
# 1. 检查服务是否运行
pm2 status
netstat -tlnp | grep 3001
netstat -tlnp | grep 3002

# 2. 检查防火墙
firewall-cmd --list-ports
firewall-cmd --permanent --add-port=3001/tcp
firewall-cmd --permanent --add-port=3002/tcp
firewall-cmd --reload

# 3. 检查阿里云安全组（最重要！）
# 必须在阿里云控制台开放端口
```

### 4. npm 安装速度慢

**问题**：npm/pnpm 安装依赖很慢

**解决**：
```bash
# 使用淘宝镜像
npm config set registry https://registry.npmmirror.com
pnpm config set registry https://registry.npmmirror.com

# 验证
npm config get registry
```

### 5. 内存不足

**问题**：1GB 内存服务器运行卡顿

**解决**：
```bash
# 创建 swap 空间
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# 永久启用
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# 验证
free -h
```

### 6. PM2 开机自启失败

**问题**：服务器重启后 PM2 服务没有自动启动

**解决**：
```bash
# 重新配置开机自启
pm2 startup systemd -u root --hp /root
pm2 save

# 测试
systemctl status pm2-root
```

### 7. Git clone 失败

**问题**：无法克隆 GitHub 仓库

**解决**：
```bash
# 方法 1：使用 HTTPS 而不是 SSH
git clone https://github.com/diyishaoshuai/qqAiChatBot.git

# 方法 2：配置 Git 代理（如果有）
git config --global http.proxy http://proxy-server:port

# 方法 3：使用 Gitee 镜像（如果有）
```

### 8. Nginx 403 错误

**问题**：访问网站显示 403 Forbidden

**解决**：
```bash
# 检查 SELinux
getenforce
# 如果是 Enforcing，设置 SELinux 上下文
chcon -R -t httpd_sys_content_t /root/qqchatbot/dist

# 或者临时关闭 SELinux
setenforce 0

# 检查文件权限
chmod -R 755 /root/qqchatbot/dist
```

---

## 维护命令

### PM2 管理

```bash
# 查看所有服务
pm2 list

# 查看日志
pm2 logs qqchatbot-server

# 实时日志
pm2 logs qqchatbot-server --lines 100

# 重启服务
pm2 restart qqchatbot-server

# 停止服务
pm2 stop qqchatbot-server

# 删除服务
pm2 delete qqchatbot-server

# 监控
pm2 monit

# 清空日志
pm2 flush
```

### MongoDB 管理

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

# 备份数据库
mongodump --db qqchatbot --out /backup/mongodb/

# 恢复数据库
mongorestore --db qqchatbot /backup/mongodb/qqchatbot/
```

### 系统管理

```bash
# 查看系统资源
top
htop  # 需要安装: yum install -y htop

# 查看磁盘使用
df -h

# 查看内存使用
free -h

# 查看端口占用
netstat -tlnp
ss -tlnp

# 查看防火墙状态
firewall-cmd --state
firewall-cmd --list-all

# 查看系统日志
journalctl -xe
```

---

## 更新部署

当代码更新后，重新部署：

```bash
cd /root/qqchatbot
./deploy-aliyun.sh
```

或手动更新：

```bash
cd /root/qqchatbot
git pull
pnpm install
pnpm build
cd server
pnpm install --prod
pm2 restart qqchatbot-server
```

---

## 安全建议

1. **修改默认密码**：务必修改 `.env` 中的 `ADMIN_PASSWORD` 和 `JWT_SECRET`
2. **配置防火墙**：只开放必要端口
3. **使用 HTTPS**：配置 SSL 证书
4. **定期更新**：保持系统和依赖包更新
5. **备份数据**：定期备份 MongoDB 数据
6. **监控日志**：定期检查服务日志
7. **限制访问**：使用 Nginx 限制 API 访问频率
8. **配置 SELinux**：不要完全关闭，正确配置权限

---

## 性能优化

1. **启用 Gzip 压缩**（Nginx）
2. **配置静态资源缓存**
3. **使用 CDN**（如果有域名）
4. **优化 MongoDB 索引**
5. **限制历史消息数量**
6. **配置 swap 空间**（小内存服务器）

---

## 联系支持

如果遇到问题：
1. 查看项目 [GitHub Issues](https://github.com/diyishaoshuai/qqAiChatBot/issues)
2. 提交新的 Issue
3. 查看项目文档

---

**祝部署顺利！** 🚀
