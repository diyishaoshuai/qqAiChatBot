# ==========================================
# QQ ChatBot Windows 部署脚本
# ==========================================
# 用途：在 Windows 服务器上自动化部署
# 使用方法：.\deploy-windows.ps1

$ErrorActionPreference = "Stop"

Write-Host "🚀 开始部署 QQ ChatBot..." -ForegroundColor Green

# 配置变量
$PROJECT_DIR = "C:\qqchatbot"
$REPO_URL = "git@github.com:diyishaoshuai/qqAiChatBot.git"
$BRANCH = "main"

# 1. 检查必要的依赖
Write-Host "📦 检查系统依赖..." -ForegroundColor Green

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 需要安装 Node.js 18+" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 需要安装 pnpm" -ForegroundColor Red
    Write-Host "运行: npm install -g pnpm" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 需要安装 git" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 依赖检查完成" -ForegroundColor Green

# 2. 克隆或更新代码
if (Test-Path $PROJECT_DIR) {
    Write-Host "📥 更新代码..." -ForegroundColor Green
    Set-Location $PROJECT_DIR
    git fetch origin
    git reset --hard origin/$BRANCH
    git pull origin $BRANCH
} else {
    Write-Host "📥 克隆代码..." -ForegroundColor Green
    git clone -b $BRANCH $REPO_URL $PROJECT_DIR
    Set-Location $PROJECT_DIR
}

# 3. 检查环境变量文件
if (-not (Test-Path "$PROJECT_DIR\server\.env")) {
    Write-Host "❌ 未找到 server\.env 文件" -ForegroundColor Red
    Write-Host "请复制 server\.env.example 为 server\.env 并填入配置" -ForegroundColor Yellow
    exit 1
}

# 4. 安装依赖
Write-Host "📦 安装后端依赖..." -ForegroundColor Green
Set-Location "$PROJECT_DIR\server"
pnpm install --prod

Write-Host "📦 安装前端依赖..." -ForegroundColor Green
Set-Location $PROJECT_DIR
pnpm install

# 5. 构建前端
Write-Host "🔨 构建前端..." -ForegroundColor Green
pnpm build

# 6. 停止旧服务（如果使用 pm2）
Write-Host "🛑 停止旧服务..." -ForegroundColor Green
if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    pm2 stop qqchatbot-server 2>$null
    pm2 delete qqchatbot-server 2>$null
}

# 7. 启动新服务
Write-Host "🚀 启动后端服务..." -ForegroundColor Green
Set-Location "$PROJECT_DIR\server"

if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    # 使用 PM2
    pm2 start index.js --name qqchatbot-server
    pm2 save
    Write-Host "✅ 使用 PM2 启动服务" -ForegroundColor Green
} else {
    # 使用 Windows 服务或后台运行
    Write-Host "⚠️  未安装 PM2，建议安装: npm install -g pm2" -ForegroundColor Yellow
    Write-Host "手动启动服务: cd $PROJECT_DIR\server && node index.js" -ForegroundColor Yellow
}

# 8. 显示服务状态
Write-Host ""
Write-Host "✅ 部署完成！" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "📡 API 服务: http://127.0.0.1:3002" -ForegroundColor Green
Write-Host "🔌 WebSocket: ws://127.0.0.1:3001" -ForegroundColor Green
Write-Host "🌐 前端文件: $PROJECT_DIR\dist" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "💡 提示：" -ForegroundColor Yellow
Write-Host "  - 查看日志: pm2 logs qqchatbot-server"
Write-Host "  - 重启服务: pm2 restart qqchatbot-server"
Write-Host "  - 停止服务: pm2 stop qqchatbot-server"
Write-Host "  - 配置 NapCat 反向 WebSocket: ws://127.0.0.1:3001"

if (Get-Command pm2 -ErrorAction SilentlyContinue) {
    Write-Host ""
    pm2 status
}
