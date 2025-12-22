#!/bin/bash
set -e

yum install -y curl git

curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

yum install -y nginx podman podman-docker

systemctl start podman.socket
systemctl enable podman.socket

podman run -d --name mongodb --restart always -p 27017:27017 -v /data/mongodb:/data/db docker.io/library/mongo:6.0 || echo "MongoDB容器启动失败，请稍后手动启动"

npm install -g pnpm pm2

cd /root
if [ -d "qqchatbot" ]; then
    cd qqchatbot
    git pull
else
    git clone https://github.com/diyishaoshuai/qqAiChatBot.git qqchatbot
    cd qqchatbot
fi

cd server
pnpm install
if [ ! -f .env ]; then
    cp env.example .env
fi

cd ..
pnpm install
pnpm build

cd server
pm2 delete qqchatbot 2>/dev/null || true
pm2 start index.js --name qqchatbot
pm2 save
pm2 startup

cat > /etc/nginx/conf.d/qqchatbot.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location /bot/ {
        root /var/www;
        try_files $uri $uri/ /bot/index.html;
        index index.html;
    }

    location = /bot {
        return 301 /bot/;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:3002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

nginx -t
systemctl restart nginx
systemctl enable nginx

systemctl start firewalld 2>/dev/null || true
systemctl enable firewalld 2>/dev/null || true
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=3001/tcp
firewall-cmd --permanent --add-port=3002/tcp
firewall-cmd --reload

curl -o /tmp/napcat.sh https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh
chmod +x /tmp/napcat.sh

echo "部署完成"
echo "请运行: bash /tmp/napcat.sh"
echo "选择Docker安装，填入你的QQ号，模式选择: reverse_ws"

