# ==========================================
# 配置 SSH 密钥免密登录
# ==========================================
# 用途：自动配置 SSH 密钥，实现免密登录
# 使用方法：.\setup-ssh-key.ps1 -ServerIP "your-ip" -Password "your-password"

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
    [string]$SSHKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
)

$ErrorActionPreference = "Stop"

Write-Host "配置 SSH 密钥免密登录" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 检查并创建 .ssh 目录
$sshDir = Split-Path $SSHKeyPath -Parent
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    Write-Host "创建 SSH 目录: $sshDir" -ForegroundColor Green
}

# 检查是否已有密钥
if (-not (Test-Path $SSHKeyPath)) {
    Write-Host "生成 SSH 密钥对..." -ForegroundColor Yellow
    $keygenArgs = @("-t", "rsa", "-b", "4096", "-f", $SSHKeyPath, "-N", '""', "-q")
    $keygenProcess = Start-Process -FilePath "ssh-keygen" -ArgumentList $keygenArgs -Wait -PassThru -NoNewWindow
    
    if ($keygenProcess.ExitCode -ne 0) {
        Write-Host "生成 SSH 密钥失败" -ForegroundColor Red
        exit 1
    }
    Write-Host "SSH 密钥已生成" -ForegroundColor Green
} else {
    Write-Host "发现现有 SSH 密钥" -ForegroundColor Green
}

# 读取公钥
$publicKeyPath = "$SSHKeyPath.pub"
if (-not (Test-Path $publicKeyPath)) {
    Write-Host "公钥文件不存在: $publicKeyPath" -ForegroundColor Red
    exit 1
}

$publicKey = Get-Content $publicKeyPath -Raw
$publicKey = $publicKey.Trim()

Write-Host ""
Write-Host "上传公钥到服务器..." -ForegroundColor Yellow
Write-Host "服务器: ${Username}@${ServerIP}:${Port}" -ForegroundColor Gray
Write-Host ""
Write-Host "需要输入密码来上传公钥" -ForegroundColor Yellow
Write-Host "请在提示时输入密码: $Password" -ForegroundColor Gray
Write-Host ""

# 方法1: 使用 type 命令通过管道上传
Write-Host "尝试使用管道上传公钥..." -ForegroundColor Yellow
Write-Host "请在提示时输入密码: $Password" -ForegroundColor Gray
Write-Host ""

# 创建临时脚本文件
$tempScript = [System.IO.Path]::GetTempFileName()
$bashScript = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
"@
$bashScript | Out-File -FilePath $tempScript -Encoding ASCII

try {
    # 使用 type 命令通过管道上传
    Get-Content $publicKeyPath | ssh -p $Port -o StrictHostKeyChecking=no "${Username}@${ServerIP}" "bash -s" < $tempScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "公钥上传成功" -ForegroundColor Green
    } else {
        throw "上传失败，退出码: $LASTEXITCODE"
    }
    Remove-Item $tempScript -ErrorAction SilentlyContinue
} catch {
    Remove-Item $tempScript -ErrorAction SilentlyContinue
    Write-Host "方法1失败，请手动配置" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "手动配置步骤：" -ForegroundColor Yellow
    Write-Host "1. 复制以下公钥内容：" -ForegroundColor Yellow
    Write-Host $publicKey -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. SSH 登录服务器：" -ForegroundColor Yellow
    Write-Host "   ssh -p $Port ${Username}@${ServerIP}" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. 登录后执行以下命令：" -ForegroundColor Yellow
    Write-Host "   mkdir -p ~/.ssh" -ForegroundColor Cyan
    Write-Host "   chmod 700 ~/.ssh" -ForegroundColor Cyan
    Write-Host "   echo '$publicKey' >> ~/.ssh/authorized_keys" -ForegroundColor Cyan
    Write-Host "   chmod 600 ~/.ssh/authorized_keys" -ForegroundColor Cyan
    Write-Host ""
    
    $manual = Read-Host "是否已手动配置完成？(y/n)"
    if ($manual -ne "y") {
        Write-Host "配置未完成" -ForegroundColor Red
        exit 1
    }
}

# 测试免密登录
Write-Host ""
Write-Host "测试免密登录..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

try {
    $testResult = & ssh -i $SSHKeyPath -p $Port -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${Username}@${ServerIP}" "echo '免密登录成功'" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SSH 免密登录配置成功！" -ForegroundColor Green
        Write-Host ""
        Write-Host "现在可以使用以下命令免密登录：" -ForegroundColor Yellow
        Write-Host "  ssh -i $SSHKeyPath ${Username}@${ServerIP}" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "或者使用部署脚本：" -ForegroundColor Yellow
        Write-Host "  .\deploy-ssh.ps1 -ServerIP `"$ServerIP`" -SSHKeyPath `"$SSHKeyPath`"" -ForegroundColor Cyan
    } else {
        Write-Host "免密登录测试失败" -ForegroundColor Yellow
        Write-Host "错误信息: $testResult" -ForegroundColor Gray
        Write-Host ""
        Write-Host "请检查：" -ForegroundColor Yellow
        Write-Host "  1. 公钥是否正确添加到服务器的 ~/.ssh/authorized_keys" -ForegroundColor Yellow
        Write-Host "  2. 服务器上的权限是否正确 (chmod 700 ~/.ssh, chmod 600 ~/.ssh/authorized_keys)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "免密登录测试失败: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "配置完成" -ForegroundColor Green
