# ==========================================
# 配置 SSH 密钥免密登录（简化版）
# ==========================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerIP = "120.26.41.79",
    
    [Parameter(Mandatory=$false)]
    [string]$Password = "Aa1305784515",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "root",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 22
)

$ErrorActionPreference = "Stop"

Write-Host "配置 SSH 密钥免密登录" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# SSH 密钥路径
$sshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
$sshDir = Split-Path $sshKeyPath -Parent

# 检查并创建 .ssh 目录
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    Write-Host "创建 SSH 目录: $sshDir" -ForegroundColor Green
}

# 检查是否已有密钥
if (-not (Test-Path $sshKeyPath)) {
    Write-Host "生成 SSH 密钥对..." -ForegroundColor Yellow
    ssh-keygen -t rsa -b 4096 -f $sshKeyPath -N '""' -q
    Write-Host "SSH 密钥已生成" -ForegroundColor Green
} else {
    Write-Host "发现现有 SSH 密钥" -ForegroundColor Green
}

# 读取公钥
$publicKeyPath = "$sshKeyPath.pub"
$publicKey = Get-Content $publicKeyPath -Raw
$publicKey = $publicKey.Trim()

Write-Host ""
Write-Host "公钥内容：" -ForegroundColor Yellow
Write-Host $publicKey -ForegroundColor Cyan
Write-Host ""

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "请按照以下步骤手动配置：" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. SSH 登录服务器（需要输入密码）：" -ForegroundColor Yellow
Write-Host "   ssh -p $Port $Username@$ServerIP" -ForegroundColor Cyan
Write-Host "   密码: $Password" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 登录后执行以下命令：" -ForegroundColor Yellow
Write-Host "   mkdir -p ~/.ssh" -ForegroundColor Cyan
Write-Host "   chmod 700 ~/.ssh" -ForegroundColor Cyan
Write-Host "   echo '$publicKey' >> ~/.ssh/authorized_keys" -ForegroundColor Cyan
Write-Host "   chmod 600 ~/.ssh/authorized_keys" -ForegroundColor Cyan
Write-Host "   exit" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. 配置完成后，按任意键继续测试..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 等待用户完成配置
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# 测试免密登录
Write-Host ""
Write-Host "测试免密登录..." -ForegroundColor Yellow

$testCmd = "ssh -i `"$sshKeyPath`" -p $Port -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${Username}@${ServerIP} echo '免密登录成功'"
$testResult = Invoke-Expression $testCmd 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "SSH 免密登录配置成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "现在可以使用以下命令免密登录：" -ForegroundColor Yellow
    Write-Host "  ssh -i $sshKeyPath ${Username}@${ServerIP}" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "或者使用部署脚本：" -ForegroundColor Yellow
    Write-Host "  .\deploy-ssh.ps1 -ServerIP `"$ServerIP`" -SSHKeyPath `"$sshKeyPath`"" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "免密登录测试失败" -ForegroundColor Red
    Write-Host "请检查配置是否正确" -ForegroundColor Yellow
}

Write-Host ""

