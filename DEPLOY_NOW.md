# 快速部署指南

由于 PowerShell 模块安装限制，请按照以下步骤手动部署：

## 方法一：使用 SSH 密钥（推荐，只需配置一次）

### 1. 配置 SSH 密钥免密登录

在 PowerShell 中执行：

```powershell
# 生成 SSH 密钥（如果还没有）
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa -N '""'

# 复制公钥到服务器（需要输入密码）
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@120.26.41.79 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### 2. 执行部署

配置好密钥后，直接运行：

```powershell
.\deploy-ssh.ps1 -ServerIP "120.26.41.79" -SSHKeyPath "$env:USERPROFILE\.ssh\id_rsa"
```

## 方法二：直接在服务器上执行（最简单）

### 1. SSH 登录服务器

```powershell
ssh root@120.26.41.79
# 输入密码: Aa1305784515
```

### 2. 在服务器上执行部署脚本

登录后，执行以下命令：

```bash
# 下载部署脚本
curl -o /tmp/deploy.sh https://raw.githubusercontent.com/diyishaoshuai/qqAiChatBot/main/deploy-aliyun.sh

# 或者如果服务器上已有项目，直接执行
cd /root/qqchatbot
bash deploy-aliyun.sh
```

## 方法三：使用 WinSCP + PuTTY（图形界面）

1. 下载 WinSCP 和 PuTTY
2. 使用 WinSCP 上传 `deploy-aliyun.sh` 到服务器
3. 使用 PuTTY 登录服务器执行脚本

## 方法四：手动执行部署命令

如果以上方法都不方便，可以手动在服务器上执行以下命令：

```bash
# 1. 安装依赖（如果还没有）
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs
npm install -g pnpm pm2

# 2. 克隆或更新代码
cd /root
if [ -d "qqchatbot" ]; then
  cd qqchatbot
  git pull
else
  git clone https://github.com/diyishaoshuai/qqAiChatBot.git qqchatbot
  cd qqchatbot
fi

# 3. 配置环境变量
cd server
if [ ! -f ".env" ]; then
  cp env.example .env
  # 编辑 .env 文件，填入你的配置
  vi .env
fi

# 4. 安装依赖
pnpm install --prod
cd ..
pnpm install

# 5. 构建前端
pnpm build

# 6. 启动服务
cd server
pm2 start index.js --name qqchatbot-server
pm2 save
pm2 startup systemd -u root --hp /root
```

## 当前服务器信息

- **IP**: 120.26.41.79
- **用户名**: root
- **密码**: Aa1305784515
- **端口**: 22

## 部署后检查

```bash
# 查看服务状态
pm2 status

# 查看日志
pm2 logs qqchatbot-server

# 检查端口
netstat -tlnp | grep -E '3001|3002'
```

## 配置 NapCat

在 NapCat 中配置反向 WebSocket：
- 地址：`ws://120.26.41.79:3001`

