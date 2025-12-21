# ==========================================
# QQ ChatBot SSH 远程部署脚本（简化版）
# ==========================================
# 用途：通过 SSH 从 Windows 部署到 Linux 云服务器（支持密码认证）
# 使用方法：.\deploy-ssh-simple.ps1 -ServerIP "your-ip" -Password "your-password"

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "root",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 22,
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectDir = "/root/qqchatbot",
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 QQ ChatBot SSH 远程部署工具" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 检查 Posh-SSH 模块
$hasPoshSSH = $false
try {
    Import-Module Posh-SSH -ErrorAction Stop
    $hasPoshSSH = $true
    Write-Host "✅ 使用 Posh-SSH 模块进行连接" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Posh-SSH 模块未安装" -ForegroundColor Yellow
    Write-Host "正在尝试安装 Posh-SSH 模块..." -ForegroundColor Yellow
    
    try {
        Install-Module -Name Posh-SSH -Scope CurrentUser -Force -SkipPublisherCheck
        Import-Module Posh-SSH
        $hasPoshSSH = $true
        Write-Host "✅ Posh-SSH 模块安装成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ 无法安装 Posh-SSH 模块: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "请手动安装：" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name Posh-SSH -Scope CurrentUser" -ForegroundColor Cyan
        exit 1
    }
}

# 建立 SSH 连接
Write-Host "🔍 连接到服务器 ${Username}@${ServerIP}:${Port} ..." -ForegroundColor Yellow

try {
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
    
    $session = New-SSHSession -ComputerName $ServerIP -Port $Port -Credential $credential -AcceptKey -ErrorAction Stop
    
    if (-not $session) {
        throw "无法建立 SSH 连接"
    }
    
    Write-Host "✅ SSH 连接成功" -ForegroundColor Green
} catch {
    Write-Host "❌ SSH 连接失败: $_" -ForegroundColor Red
    exit 1
}

# 读取部署脚本模板（使用现有的 deploy-aliyun.sh 作为基础）
Write-Host ""
Write-Host "📤 准备部署脚本..." -ForegroundColor Yellow

# 构建部署命令（直接执行，不创建文件）
$deployCommands = @"
set -e
PROJECT_DIR='$ProjectDir'
REPO_URL='https://github.com/diyishaoshuai/qqAiChatBot.git'
BRANCH='$Branch'

echo '🚀 开始部署 QQ ChatBot...'

# 检查依赖
echo '📦 检查系统依赖...'
command -v node >/dev/null 2>&1 || { echo '❌ 需要安装 Node.js 18+'; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo '❌ 需要安装 pnpm'; exit 1; }
command -v git >/dev/null 2>&1 || { echo '❌ 需要安装 git'; exit 1; }
command -v pm2 >/dev/null 2>&1 || { echo '⚠️  未检测到 PM2，正在安装...'; npm install -g pm2; }

echo '✅ 依赖检查完成'

# 克隆或更新代码
if [ -d \"`$PROJECT_DIR\" ]; then
  echo '📥 更新代码...'
  cd \"`$PROJECT_DIR\"
  git fetch origin
  git reset --hard origin/`$BRANCH
  git pull origin `$BRANCH
else
  echo '📥 克隆代码...'
  git clone -b `$BRANCH `$REPO_URL `$PROJECT_DIR
  cd \"`$PROJECT_DIR\"
fi

# 检查环境变量文件
if [ ! -f \"`$PROJECT_DIR/server/.env\" ]; then
  echo '⚠️  未找到 server/.env 文件'
  if [ -f \"`$PROJECT_DIR/server/env.example\" ]; then
    echo '正在从 env.example 创建 .env 文件...'
    cp \"`$PROJECT_DIR/server/env.example\" \"`$PROJECT_DIR/server/.env\"
    echo '⚠️  请务必编辑 `$PROJECT_DIR/server/.env 文件并填入正确的配置！'
  else
    echo '❌ 未找到 server/.env 和 server/env.example 文件'
    exit 1
  fi
fi

# 安装依赖
echo '📦 安装后端依赖...'
cd \"`$PROJECT_DIR/server\"
pnpm install --prod

echo '📦 安装前端依赖...'
cd \"`$PROJECT_DIR\"
pnpm install

# 构建前端
echo '🔨 构建前端...'
pnpm build

# 停止旧服务
echo '🛑 停止旧服务...'
pm2 stop qqchatbot-server 2>/dev/null || true
pm2 delete qqchatbot-server 2>/dev/null || true

# 启动新服务
echo '🚀 启动后端服务...'
cd \"`$PROJECT_DIR/server\"
pm2 start index.js --name qqchatbot-server --node-args='--max-old-space-size=512'
pm2 save

# 配置开机自启
pm2 startup systemd -u `$USER --hp `$HOME 2>/dev/null || true

# 显示服务状态
echo ''
echo '✅ 部署完成！'
echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
pm2 status
echo ''
echo '📡 API 服务: http://127.0.0.1:3002'
echo '🔌 WebSocket: ws://127.0.0.1:3001'
echo '🌐 前端文件: `$PROJECT_DIR/dist'
"@

# 在服务器上执行部署命令
Write-Host ""
Write-Host "🚀 开始在服务器上执行部署..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""

try {
    $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "bash -c `"$deployCommands`""
    
    # 显示输出
    Write-Host $result.Output
    
    if ($result.ExitStatus -ne 0) {
        Write-Host ""
        Write-Host "❌ 部署执行失败" -ForegroundColor Red
        if ($result.Error) {
            Write-Host "错误信息: $($result.Error)" -ForegroundColor Red
        }
        Remove-SSHSession -SessionId $session.SessionId | Out-Null
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "❌ 部署失败: $_" -ForegroundColor Red
    Remove-SSHSession -SessionId $session.SessionId | Out-Null
    exit 1
}

# 清理
Remove-SSHSession -SessionId $session.SessionId | Out-Null

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ 部署完成！" -ForegroundColor Green
Write-Host ""
Write-Host "💡 后续操作：" -ForegroundColor Yellow
Write-Host "  1. 如果首次部署，请编辑服务器上的 .env 文件：" -ForegroundColor Yellow
Write-Host "     ssh ${Username}@${ServerIP} 'vi ${ProjectDir}/server/.env'" -ForegroundColor Cyan
Write-Host "  2. 查看服务日志：" -ForegroundColor Yellow
Write-Host "     ssh ${Username}@${ServerIP} 'pm2 logs qqchatbot-server'" -ForegroundColor Cyan
Write-Host "  3. 重启服务：" -ForegroundColor Yellow
Write-Host "     ssh ${Username}@${ServerIP} 'pm2 restart qqchatbot-server'" -ForegroundColor Cyan
Write-Host ""

