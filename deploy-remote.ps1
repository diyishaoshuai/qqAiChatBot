# ==========================================
# QQ ChatBot 远程部署脚本
# ==========================================
# 用途：通过 SSH 上传并执行部署脚本
# 使用方法：.\deploy-remote.ps1 -ServerIP "your-ip" -Password "your-password"

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "root",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 22
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 QQ ChatBot 远程部署工具" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 检查 Posh-SSH 模块
$hasPoshSSH = $false
try {
    Import-Module Posh-SSH -ErrorAction Stop
    $hasPoshSSH = $true
    Write-Host "✅ 使用 Posh-SSH 模块" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Posh-SSH 模块未安装，正在安装..." -ForegroundColor Yellow
    try {
        Install-Module -Name Posh-SSH -Scope CurrentUser -Force -SkipPublisherCheck
        Import-Module Posh-SSH
        $hasPoshSSH = $true
        Write-Host "✅ Posh-SSH 模块安装成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ 无法安装 Posh-SSH 模块: $_" -ForegroundColor Red
        Write-Host "请手动安装: Install-Module -Name Posh-SSH -Scope CurrentUser" -ForegroundColor Yellow
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

# 上传部署脚本
Write-Host ""
Write-Host "📤 上传部署脚本到服务器..." -ForegroundColor Yellow

$deployScriptPath = Join-Path $PSScriptRoot "deploy-aliyun.sh"
if (-not (Test-Path $deployScriptPath)) {
    Write-Host "❌ 未找到部署脚本: $deployScriptPath" -ForegroundColor Red
    Remove-SSHSession -SessionId $session.SessionId | Out-Null
    exit 1
}

try {
    Set-SCPFile -ComputerName $ServerIP -Port $Port -Credential $credential -LocalFile $deployScriptPath -RemotePath "/tmp/deploy-qqchatbot.sh" -AcceptKey
    Write-Host "✅ 脚本上传成功" -ForegroundColor Green
} catch {
    Write-Host "❌ 上传脚本失败: $_" -ForegroundColor Red
    Remove-SSHSession -SessionId $session.SessionId | Out-Null
    exit 1
}

# 执行部署脚本
Write-Host ""
Write-Host "🚀 开始在服务器上执行部署..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""

try {
    # 设置执行权限并执行
    $chmodResult = Invoke-SSHCommand -SessionId $session.SessionId -Command "chmod +x /tmp/deploy-qqchatbot.sh"
    
    $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "bash /tmp/deploy-qqchatbot.sh"
    
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
Write-Host "  1. 如果首次部署，请编辑服务器上的 .env 文件" -ForegroundColor Yellow
$cmd1 = "ssh ${Username}@${ServerIP} 'vi /root/qqchatbot/server/.env'"
Write-Host "     $cmd1" -ForegroundColor Cyan
Write-Host "  2. 查看服务日志" -ForegroundColor Yellow
$cmd2 = "ssh ${Username}@${ServerIP} 'pm2 logs qqchatbot-server'"
Write-Host "     $cmd2" -ForegroundColor Cyan
Write-Host "  3. 重启服务" -ForegroundColor Yellow
$cmd3 = "ssh ${Username}@${ServerIP} 'pm2 restart qqchatbot-server'"
Write-Host "     $cmd3" -ForegroundColor Cyan
Write-Host ""

