# ==========================================
# QQ ChatBot SSH 远程部署脚本（支持密码）
# ==========================================
# 用途：通过 SSH 从 Windows 部署到 Linux 云服务器（支持密码认证）
# 使用方法：.\deploy-ssh-with-password.ps1 -ServerIP "your-ip" -Password "your-password"

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

Write-Host "🚀 QQ ChatBot SSH 远程部署工具（密码认证）" -ForegroundColor Cyan
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
        Write-Host ""
        Write-Host "或者先配置 SSH 密钥免密登录，然后使用 deploy-ssh.ps1" -ForegroundColor Yellow
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

# 构建部署脚本
$deployScript = @"
#!/bin/bash
set -e

echo "🚀 开始部署 QQ ChatBot..."

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$ProjectDir"
REPO_URL="https://github.com/diyishaoshuai/qqAiChatBot.git"
BRANCH="$Branch"

# 1. 检查必要的依赖
echo -e "`${GREEN}📦 检查系统依赖...`${NC}"
command -v node >/dev/null 2>&1 || { echo -e "`${RED}❌ 需要安装 Node.js 18+`${NC}"; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo -e "`${RED}❌ 需要安装 pnpm`${NC}"; exit 1; }
command -v git >/dev/null 2>&1 || { echo -e "`${RED}❌ 需要安装 git`${NC}"; exit 1; }
command -v pm2 >/dev/null 2>&1 || { echo -e "`${YELLOW}⚠️  未检测到 PM2，正在安装...`${NC}"; npm install -g pm2; }

echo -e "`${GREEN}✅ 依赖检查完成`${NC}"

# 2. 克隆或更新代码
if [ -d "`$PROJECT_DIR" ]; then
  echo -e "`${GREEN}📥 更新代码...`${NC}"
  cd "`$PROJECT_DIR"
  git fetch origin
  git reset --hard origin/`$BRANCH
  git pull origin `$BRANCH
else
  echo -e "`${GREEN}📥 克隆代码...`${NC}"
  git clone -b `$BRANCH `$REPO_URL `$PROJECT_DIR
  cd "`$PROJECT_DIR"
fi

# 3. 检查环境变量文件
if [ ! -f "`$PROJECT_DIR/server/.env" ]; then
  echo -e "`${YELLOW}⚠️  未找到 server/.env 文件`${NC}"
  if [ -f "`$PROJECT_DIR/server/env.example" ]; then
    echo -e "`${YELLOW}正在从 env.example 创建 .env 文件...`${NC}"
    cp "`$PROJECT_DIR/server/env.example" "`$PROJECT_DIR/server/.env"
    echo -e "`${RED}⚠️  请务必编辑 `$PROJECT_DIR/server/.env 文件并填入正确的配置！`${NC}"
  else
    echo -e "`${RED}❌ 未找到 server/.env 和 server/env.example 文件`${NC}"
    exit 1
  fi
fi

# 4. 安装依赖
echo -e "`${GREEN}📦 安装后端依赖...`${NC}"
cd "`$PROJECT_DIR/server"
pnpm install --prod

echo -e "`${GREEN}📦 安装前端依赖...`${NC}"
cd "`$PROJECT_DIR"
pnpm install

# 5. 构建前端
echo -e "`${GREEN}🔨 构建前端...`${NC}"
pnpm build

# 6. 停止旧服务
echo -e "`${GREEN}🛑 停止旧服务...`${NC}"
pm2 stop qqchatbot-server 2>/dev/null || true
pm2 delete qqchatbot-server 2>/dev/null || true

# 7. 启动新服务
echo -e "`${GREEN}🚀 启动后端服务...`${NC}"
cd "`$PROJECT_DIR/server"
pm2 start index.js --name qqchatbot-server --node-args="--max-old-space-size=512"
pm2 save

# 8. 配置开机自启
pm2 startup systemd -u `$USER --hp `$HOME 2>/dev/null || true

# 9. 显示服务状态
echo ""
echo -e "`${GREEN}✅ 部署完成！`${NC}"
echo -e "`${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`${NC}"
pm2 status
echo ""
echo -e "`${GREEN}📡 API 服务: http://127.0.0.1:3002`${NC}"
echo -e "`${GREEN}🔌 WebSocket: ws://127.0.0.1:3001`${NC}"
echo -e "`${GREEN}🌐 前端文件: `$PROJECT_DIR/dist`${NC}"
echo ""
echo -e "`${YELLOW}💡 提示：`${NC}"
echo -e "  - 查看日志: pm2 logs qqchatbot-server"
echo -e "  - 重启服务: pm2 restart qqchatbot-server"
echo -e "  - 停止服务: pm2 stop qqchatbot-server"
echo -e "  - 配置 NapCat 反向 WebSocket: ws://服务器IP:3001"
"@

# 将部署脚本写入临时文件并上传
Write-Host ""
Write-Host "📤 上传部署脚本到服务器..." -ForegroundColor Yellow

$tempScript = [System.IO.Path]::GetTempFileName()
$deployScript | Out-File -FilePath $tempScript -Encoding UTF8

try {
    # 使用 SCP 上传脚本
    $scpResult = Set-SCPFile -ComputerName $ServerIP -Port $Port -Credential $credential -LocalFile $tempScript -RemotePath "/tmp/deploy-qqchatbot.sh" -AcceptKey
    
    Write-Host "✅ 脚本上传成功" -ForegroundColor Green
} catch {
    Write-Host "❌ 上传脚本失败: $_" -ForegroundColor Red
    Remove-Item $tempScript -ErrorAction SilentlyContinue
    Remove-SSHSession -SessionId $session.SessionId | Out-Null
    exit 1
}

# 在服务器上执行部署脚本
Write-Host ""
Write-Host "🚀 开始在服务器上执行部署..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""

try {
    # 先设置执行权限
    $chmodResult = Invoke-SSHCommand -SessionId $session.SessionId -Command "chmod +x /tmp/deploy-qqchatbot.sh"
    
    # 执行部署脚本
    $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "bash /tmp/deploy-qqchatbot.sh"
    
    # 显示输出
    Write-Host $result.Output
    
    if ($result.ExitStatus -ne 0) {
        Write-Host ""
        Write-Host "❌ 部署执行失败" -ForegroundColor Red
        if ($result.Error) {
            Write-Host "错误信息: $($result.Error)" -ForegroundColor Red
        }
        Remove-Item $tempScript -ErrorAction SilentlyContinue
        Remove-SSHSession -SessionId $session.SessionId | Out-Null
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "❌ 部署失败: $_" -ForegroundColor Red
    Remove-Item $tempScript -ErrorAction SilentlyContinue
    Remove-SSHSession -SessionId $session.SessionId | Out-Null
    exit 1
}

# 清理
Remove-Item $tempScript -ErrorAction SilentlyContinue
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

