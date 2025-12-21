#!/bin/bash

# ==========================================
# QQ ChatBot 部署脚本
# ==========================================
# 用途：自动化部署到服务器
# 使用方法：./deploy.sh

set -e  # 遇到错误立即退出

echo "🚀 开始部署 QQ ChatBot..."

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 配置变量
PROJECT_DIR="/root/qqchatbot"
REPO_URL="git@github.com:diyishaoshuai/qqAiChatBot.git"
BRANCH="main"

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}⚠️  建议使用 root 用户运行此脚本${NC}"
fi

# 1. 检查必要的依赖
echo -e "${GREEN}📦 检查系统依赖...${NC}"
command -v node >/dev/null 2>&1 || { echo -e "${RED}❌ 需要安装 Node.js 18+${NC}"; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo -e "${RED}❌ 需要安装 pnpm${NC}"; exit 1; }
command -v git >/dev/null 2>&1 || { echo -e "${RED}❌ 需要安装 git${NC}"; exit 1; }
command -v mongod >/dev/null 2>&1 || { echo -e "${YELLOW}⚠️  未检测到 MongoDB，请确保 MongoDB 服务可访问${NC}"; }

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

# 8. 配置 Nginx（如果需要）
if command -v nginx >/dev/null 2>&1; then
  echo -e "${GREEN}🌐 检测到 Nginx，配置反向代理...${NC}"

  NGINX_CONF="/etc/nginx/sites-available/qqchatbot"

  if [ ! -f "$NGINX_CONF" ]; then
    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name your-domain.com;  # 修改为你的域名

    # 前端静态文件
    location / {
        root $PROJECT_DIR/dist;
        try_files \$uri \$uri/ /index.html;
    }

    # 后端 API
    location /api/ {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # WebSocket (如果需要从外部访问)
    location /ws/ {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    echo -e "${YELLOW}⚠️  请编辑 $NGINX_CONF 修改域名配置${NC}"
    echo -e "${YELLOW}⚠️  然后运行: nginx -t && systemctl reload nginx${NC}"
  fi
fi

# 9. 显示服务状态
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
echo -e "  - 配置 NapCat 反向 WebSocket: ws://127.0.0.1:3001"
