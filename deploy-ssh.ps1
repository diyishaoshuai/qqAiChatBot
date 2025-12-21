# ==========================================
# QQ ChatBot SSH 远程部署脚本
# ==========================================
# 用途：通过 SSH 从 Windows 部署到 Linux 云服务器
# 使用方法：.\deploy-ssh.ps1
#
# 需要配置：
# 1. SSH 密钥或密码
# 2. 服务器地址、用户名、端口
# 3. 服务器上已安装 Node.js、pnpm、git、PM2

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerIP = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "root",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 22,
    
    [Parameter(Mandatory=$false)]
    [string]$SSHKeyPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectDir = "/root/qqchatbot",
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 QQ ChatBot SSH 远程部署工具" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 如果没有提供服务器IP，则提示输入
if ([string]::IsNullOrEmpty($ServerIP)) {
    $ServerIP = Read-Host "请输入服务器IP地址"
}

if ([string]::IsNullOrEmpty($ServerIP)) {
    Write-Host "❌ 服务器IP地址不能为空" -ForegroundColor Red
    exit 1
}

# 提示输入用户名
if ([string]::IsNullOrEmpty($Username)) {
    $Username = Read-Host "请输入SSH用户名 (默认: root)"
    if ([string]::IsNullOrEmpty($Username)) {
        $Username = "root"
    }
}

# 检查 SSH 连接
Write-Host "🔍 检查 SSH 连接..." -ForegroundColor Yellow

$sshTest = $false
if (-not [string]::IsNullOrEmpty($SSHKeyPath)) {
    # 使用密钥文件
    if (Test-Path $SSHKeyPath) {
        $sshTest = $true
        $sshCmd = "ssh -i `"$SSHKeyPath`" -p $Port -o StrictHostKeyChecking=no $Username@$ServerIP"
    } else {
        Write-Host "⚠️  SSH密钥文件不存在: $SSHKeyPath" -ForegroundColor Yellow
    }
} else {
    # 使用密码（需要 sshpass 或手动输入）
    $sshCmd = "ssh -p $Port -o StrictHostKeyChecking=no $Username@$ServerIP"
    $sshTest = $true
}

if (-not $sshTest) {
    Write-Host "❌ 无法建立SSH连接配置" -ForegroundColor Red
    exit 1
}

# 测试SSH连接
Write-Host "测试连接到 ${Username}@${ServerIP}:${Port} ..." -ForegroundColor Yellow
try {
    if (-not [string]::IsNullOrEmpty($SSHKeyPath)) {
        $testResult = & ssh -i $SSHKeyPath -p $Port -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${Username}@${ServerIP}" "echo SSH连接成功" 2>&1
    } else {
        $testResult = & ssh -p $Port -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${Username}@${ServerIP}" "echo SSH连接成功" 2>&1
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "SSH连接失败"
    }
    Write-Host "✅ SSH 连接成功" -ForegroundColor Green
} catch {
    Write-Host "❌ SSH 连接失败: $_" -ForegroundColor Red
    Write-Host "💡 提示：" -ForegroundColor Yellow
    Write-Host "  1. 确保服务器IP、端口、用户名正确" -ForegroundColor Yellow
    Write-Host "  2. 如果使用密钥，请使用 -SSHKeyPath 参数指定密钥路径" -ForegroundColor Yellow
    Write-Host "  3. 如果使用密码，请确保已配置SSH免密登录或使用 sshpass" -ForegroundColor Yellow
    exit 1
}

# 构建部署脚本内容
$deployScript = @"
#!/bin/bash
set -e

echo "🚀 开始部署 QQ ChatBot..."

# 颜色定义
GREEN=`"\033[0;32m`"
YELLOW=`"\033[1;33m`"
RED=`"\033[0;31m`"
NC=`"\033[0m`"

PROJECT_DIR="$ProjectDir"
REPO_URL="https://github.com/diyishaoshuai/qqAiChatBot.git"
BRANCH="$Branch"

# 1. 检查必要的依赖
echo -e "\${GREEN}📦 检查系统依赖...\${NC}"
command -v node >/dev/null 2>&1 || { echo -e "\${RED}❌ 需要安装 Node.js 18+\${NC}"; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo -e "\${RED}❌ 需要安装 pnpm\${NC}"; exit 1; }
command -v git >/dev/null 2>&1 || { echo -e "\${RED}❌ 需要安装 git\${NC}"; exit 1; }
command -v pm2 >/dev/null 2>&1 || { echo -e "\${YELLOW}⚠️  未检测到 PM2，正在安装...\${NC}"; npm install -g pm2; }

echo -e "\${GREEN}✅ 依赖检查完成\${NC}"

# 2. 克隆或更新代码
if [ -d "\$PROJECT_DIR" ]; then
  echo -e "\${GREEN}📥 更新代码...\${NC}"
  cd "\$PROJECT_DIR"
  git fetch origin
  git reset --hard origin/\$BRANCH
  git pull origin \$BRANCH
else
  echo -e "\${GREEN}📥 克隆代码...\${NC}"
  git clone -b \$BRANCH \$REPO_URL \$PROJECT_DIR
  cd "\$PROJECT_DIR"
fi

# 3. 检查环境变量文件
if [ ! -f "\$PROJECT_DIR/server/.env" ]; then
  echo -e "\${YELLOW}⚠️  未找到 server/.env 文件\${NC}"
  if [ -f "\$PROJECT_DIR/server/env.example" ]; then
    echo -e "\${YELLOW}正在从 env.example 创建 .env 文件...\${NC}"
    cp "\$PROJECT_DIR/server/env.example" "\$PROJECT_DIR/server/.env"
    echo -e "\${RED}⚠️  请务必编辑 \$PROJECT_DIR/server/.env 文件并填入正确的配置！\${NC}"
  else
    echo -e "\${RED}❌ 未找到 server/.env 和 server/env.example 文件\${NC}"
    exit 1
  fi
fi

# 4. 安装依赖
echo -e "\${GREEN}📦 安装后端依赖...\${NC}"
cd "\$PROJECT_DIR/server"
pnpm install --prod

echo -e "\${GREEN}📦 安装前端依赖...\${NC}"
cd "\$PROJECT_DIR"
pnpm install

# 5. 构建前端
echo -e "\${GREEN}🔨 构建前端...\${NC}"
pnpm build

# 6. 停止旧服务
echo -e "\${GREEN}🛑 停止旧服务...\${NC}"
pm2 stop qqchatbot-server 2>/dev/null || true
pm2 delete qqchatbot-server 2>/dev/null || true

# 7. 启动新服务
echo -e "\${GREEN}🚀 启动后端服务...\${NC}"
cd "\$PROJECT_DIR/server"
pm2 start index.js --name qqchatbot-server --node-args="--max-old-space-size=512"
pm2 save

# 8. 配置开机自启
pm2 startup systemd -u \$USER --hp \$HOME 2>/dev/null || true

# 9. 显示服务状态
echo ""
echo -e "\${GREEN}✅ 部署完成！\${NC}"
echo -e "\${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${NC}"
pm2 status
echo ""
echo -e "\${GREEN}📡 API 服务: http://127.0.0.1:3002\${NC}"
echo -e "\${GREEN}🔌 WebSocket: ws://127.0.0.1:3001\${NC}"
echo -e "\${GREEN}🌐 前端文件: \$PROJECT_DIR/dist\${NC}"
echo ""
echo -e "\${YELLOW}💡 提示：\${NC}"
echo -e "  - 查看日志: pm2 logs qqchatbot-server"
echo -e "  - 重启服务: pm2 restart qqchatbot-server"
echo -e "  - 停止服务: pm2 stop qqchatbot-server"
echo -e "  - 配置 NapCat 反向 WebSocket: ws://服务器IP:3001"
"@

# 将部署脚本写入临时文件
$tempScript = [System.IO.Path]::GetTempFileName()
$deployScript | Out-File -FilePath $tempScript -Encoding UTF8

Write-Host ""
Write-Host "📤 上传部署脚本到服务器..." -ForegroundColor Yellow

# 上传脚本到服务器
try {
    if (-not [string]::IsNullOrEmpty($SSHKeyPath)) {
        & scp -i $SSHKeyPath -P $Port -o StrictHostKeyChecking=no $tempScript "$Username@$ServerIP`:/tmp/deploy-qqchatbot.sh" 2>&1 | Out-Null
    } else {
        & scp -P $Port -o StrictHostKeyChecking=no $tempScript "$Username@$ServerIP`:/tmp/deploy-qqchatbot.sh" 2>&1 | Out-Null
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "上传脚本失败"
    }
    Write-Host "✅ 脚本上传成功" -ForegroundColor Green
} catch {
    Write-Host "❌ 上传脚本失败: $_" -ForegroundColor Red
    Remove-Item $tempScript -ErrorAction SilentlyContinue
    exit 1
}

# 在服务器上执行部署脚本
Write-Host ""
Write-Host "🚀 开始在服务器上执行部署..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""

try {
    if (-not [string]::IsNullOrEmpty($SSHKeyPath)) {
        & ssh -i $SSHKeyPath -p $Port -o StrictHostKeyChecking=no "$Username@$ServerIP" "chmod +x /tmp/deploy-qqchatbot.sh && bash /tmp/deploy-qqchatbot.sh"
    } else {
        & ssh -p $Port -o StrictHostKeyChecking=no "$Username@$ServerIP" "chmod +x /tmp/deploy-qqchatbot.sh && bash /tmp/deploy-qqchatbot.sh"
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "部署执行失败"
    }
} catch {
    Write-Host ""
    Write-Host "❌ 部署失败: $_" -ForegroundColor Red
    Remove-Item $tempScript -ErrorAction SilentlyContinue
    exit 1
}

# 清理临时文件
Remove-Item $tempScript -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ 部署完成！" -ForegroundColor Green
Write-Host ""
Write-Host "💡 后续操作：" -ForegroundColor Yellow
Write-Host "  1. 如果首次部署，请编辑服务器上的 .env 文件：" -ForegroundColor Yellow
$cmd1 = "ssh ${Username}@${ServerIP} `"vi ${ProjectDir}/server/.env`""
Write-Host "     $cmd1" -ForegroundColor Cyan
Write-Host "  2. 查看服务日志：" -ForegroundColor Yellow
$cmd2 = "ssh ${Username}@${ServerIP} `"pm2 logs qqchatbot-server`""
Write-Host "     $cmd2" -ForegroundColor Cyan
Write-Host "  3. 重启服务：" -ForegroundColor Yellow
$cmd3 = "ssh ${Username}@${ServerIP} `"pm2 restart qqchatbot-server`""
Write-Host "     $cmd3" -ForegroundColor Cyan
Write-Host ""

