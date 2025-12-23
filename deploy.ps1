# QQ ChatBot 自动部署脚本
# 用法: .\deploy.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QQ ChatBot 自动部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 配置
$SERVER_HOST = "120.26.41.79"
$SERVER_USER = "root"
$SSH_KEY = "$HOME\.ssh\id_rsa"
$REMOTE_DIR = "/root/qqchatbot"
$WEB_DIR = "/var/www/bot"

# 步骤1: 构建前端
Write-Host "[1/6] 构建前端项目..." -ForegroundColor Yellow
pnpm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 前端构建失败" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 前端构建完成" -ForegroundColor Green
Write-Host ""

# 步骤2: 部署前端
Write-Host "[2/6] 部署前端到服务器..." -ForegroundColor Yellow
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_HOST} "rm -rf $WEB_DIR && mkdir -p $WEB_DIR"
scp -i $SSH_KEY -o StrictHostKeyChecking=no -r dist/* ${SERVER_USER}@${SERVER_HOST}:${WEB_DIR}/
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 前端部署失败" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 前端部署完成" -ForegroundColor Green
Write-Host ""

# 步骤3: 上传后端代码
Write-Host "[3/6] 上传后端代码..." -ForegroundColor Yellow
scp -i $SSH_KEY -o StrictHostKeyChecking=no server/index.js ${SERVER_USER}@${SERVER_HOST}:${REMOTE_DIR}/server/
scp -i $SSH_KEY -o StrictHostKeyChecking=no server/package.json ${SERVER_USER}@${SERVER_HOST}:${REMOTE_DIR}/server/
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 后端代码上传失败" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 后端代码上传完成" -ForegroundColor Green
Write-Host ""

# 步骤4: 安装依赖
Write-Host "[4/6] 安装后端依赖..." -ForegroundColor Yellow
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_HOST} "cd ${REMOTE_DIR}/server && pnpm install"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 依赖安装失败" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 依赖安装完成" -ForegroundColor Green
Write-Host ""

# 步骤5: 重启后端服务
Write-Host "[5/6] 重启后端服务..." -ForegroundColor Yellow
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_HOST} "cd ${REMOTE_DIR}/server && pm2 restart qqchatbot"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 服务重启失败" -ForegroundColor Red
    exit 1
}
Write-Host "✅ 服务重启完成" -ForegroundColor Green
Write-Host ""

# 步骤6: 验证部署
Write-Host "[6/6] 验证部署结果..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$response = curl -s https://qqaibot.filingservice.cn/health
if ($response -match "ok") {
    Write-Host "✅ 后端服务运行正常" -ForegroundColor Green
} else {
    Write-Host "⚠️  后端服务可能未正常启动，请检查日志" -ForegroundColor Yellow
}

$frontendTest = curl -s https://qqaibot.filingservice.cn/bot/ -I
if ($frontendTest -match "200") {
    Write-Host "✅ 前端页面访问正常" -ForegroundColor Green
} else {
    Write-Host "⚠️  前端页面可能无法访问" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  🎉 部署完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "访问地址: https://qqaibot.filingservice.cn/bot/" -ForegroundColor Cyan
Write-Host ""
