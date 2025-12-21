#!/bin/bash

# ==========================================
# QQ ChatBot 阿里云 Linux 部署脚本
# ==========================================
# 适用系统：Alibaba Cloud Linux 3.2104 LTS
# 使用方法：./deploy-aliyun.sh

set -e  # 遇到错误立即退出

echo "🚀 开始部署 QQ ChatBot (阿里云 Linux 3.2104 LTS)..."

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_DIR="/root/qqchatbot"
REPO_URL="https://github.com/diyishaoshuai/qqAiChatBot.git"
BRANCH="main"

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  建议使用 root 用户运行此脚本${NC}"
fi

# 1. 检查并安装必要的依赖
echo -e "${GREEN}📦 检查系统依赖...${NC}"

# 检查 Node.js
if ! command -v node >/dev/null 2>&1; then
  echo -e "${YELLOW}正在安装 Node.js 18...${NC}"
  curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
  yum install -y nodejs
else
  echo -e "${GREEN}✅ Node.js 已安装: $(node -v)${NC}"
fi

# 检查 pnpm
if ! command -v pnpm >/dev/null 2>&1; then
  echo -e "${YELLOW}正在安装 pnpm...${NC}"
  npm install -g pnpm
else
  echo -e "${GREEN}✅ pnpm 已安装: $(pnpm -v)${NC}"
fi

# 检查 PM2
if ! command -v pm2 >/dev/null 2>&1; then
  echo -e "${YELLOW}正在安装 PM2...${NC}"
  npm install -g pm2
else
  echo -e "${GREEN}✅ PM2 已安装${NC}"
fi

# 检查 Git
if ! command -v git >/dev/null 2>&1; then
  echo -e "${YELLOW}正在安装 Git...${NC}"
  yum install -y git
else
  echo -e "${GREEN}✅ Git 已安装: $(git --version)${NC}"
fi

# 检查 MongoDB
if ! command -v mongod >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  未检测到 MongoDB，正在安装...${NC}"

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

  echo -e "${GREEN}✅ MongoDB 安装完成${NC}"
else
  echo -e "${GREEN}✅ MongoDB 已安装${NC}"
  # 确保 MongoDB 正在运行
  systemctl start mongod 2>/dev/null || true
fi

echo -e "${GREEN}✅ 依赖检查完成${NC}"

# 2. 克隆或更新代码
if [ -d "$PROJECT_DIR" ]; then
  echo -e "${GREEN}📥 更新代码...${NC}"
  cd "$PROJECT_DIR"
  git fetch origin
  git reset --hard origin/$BRANCH
  git pull origin $BRANCH
else
  echo -e "${GREEN}📥 克隆代码...${NC}"
  git clone -b $BRANCH $REPO_URL $PROJECT_DIR
  cd "$PROJECT_DIR"
fi

# 3. 检查环境变量文件
if [ ! -f "$PROJECT_DIR/server/.env" ]; then
  echo -e "${RED}❌ 未找到 server/.env 文件${NC}"
  echo -e "${YELLOW}请复制 server/.env.example 为 server/.env 并填入配置${NC}"
  echo -e "${YELLOW}运行以下命令配置：${NC}"
  echo -e "${YELLOW}  cd $PROJECT_DIR/server${NC}"
  echo -e "${YELLOW}  cp .env.example .env${NC}"
  echo -e "${YELLOW}  vi .env${NC}"
  exit 1
fi

# 4. 安装依赖
echo -e "${GREEN}📦 安装后端依赖...${NC}"
cd "$PROJECT_DIR/server"
pnpm install --prod

echo -e "${GREEN}📦 安装前端依赖...${NC}"
cd "$PROJECT_DIR"
pnpm install

# 5. 构建前端
echo -e "${GREEN}🔨 构建前端...${NC}"
pnpm build

# 6. 停止旧服务
echo -e "${GREEN}🛑 停止旧服务...${NC}"
pm2 stop qqchatbot-server 2>/dev/null || true
pm2 delete qqchatbot-server 2>/dev/null || true

# 7. 启动新服务
echo -e "${GREEN}🚀 启动后端服务...${NC}"
cd "$PROJECT_DIR/server"
pm2 start index.js --name qqchatbot-server --node-args="--max-old-space-size=512"
pm2 save

# 8. 配置开机自启
pm2 startup systemd -u root --hp /root 2>/dev/null || true

# 9. 配置防火墙
echo -e "${GREEN}🔥 配置防火墙...${NC}"
if command -v firewall-cmd >/dev/null 2>&1; then
  # 开放必要端口
  firewall-cmd --permanent --add-port=3001/tcp 2>/dev/null || true
  firewall-cmd --permanent --add-port=3002/tcp 2>/dev/null || true
  firewall-cmd --permanent --add-port=80/tcp 2>/dev/null || true
  firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
  firewall-cmd --reload 2>/dev/null || true
  echo -e "${GREEN}✅ 防火墙配置完成${NC}"
else
  echo -e "${YELLOW}⚠️  未检测到 firewalld，请手动配置安全组${NC}"
fi

# 10. 显示服务状态
echo -e "${GREEN}📊 服务状态：${NC}"
pm2 status

echo ""
echo -e "${GREEN}✅ 部署完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📡 API 服务: http://127.0.0.1:3002${NC}"
echo -e "${GREEN}🔌 WebSocket: ws://127.0.0.1:3001${NC}"
echo -e "${GREEN}🌐 前端文件: $PROJECT_DIR/dist${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}💡 提示：${NC}"
echo -e "  - 查看日志: pm2 logs qqchatbot-server"
echo -e "  - 重启服务: pm2 restart qqchatbot-server"
echo -e "  - 停止服务: pm2 stop qqchatbot-server"
echo -e "  - 配置 NapCat 反向 WebSocket: ws://服务器IP:3001"
echo ""
echo -e "${YELLOW}⚠️  重要提示：${NC}"
echo -e "  1. 请在阿里云控制台的安全组中开放以下端口："
echo -e "     - 3001/tcp (WebSocket)"
echo -e "     - 3002/tcp (API)"
echo -e "     - 80/tcp (HTTP，如果使用 Nginx)"
echo -e "     - 443/tcp (HTTPS，如果使用 Nginx)"
echo -e "  2. 务必修改 server/.env 中的默认密码和密钥"
echo -e "  3. 建议配置 Nginx 反向代理以提供更好的安全性"
echo ""
