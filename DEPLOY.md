# GitHub Actions 自动部署配置指南

本项目已配置 GitHub Actions 自动部署功能。当代码推送到 `main` 分支时，会自动触发构建和部署流程。

## 配置步骤

### 1. 配置 GitHub Secrets

在 GitHub 仓库中配置以下 Secrets：

1. 进入仓库页面
2. 点击 `Settings` > `Secrets and variables` > `Actions`
3. 点击 `New repository secret` 添加以下密钥：

#### 需要配置的 Secrets：

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `SSH_PRIVATE_KEY` | 服务器 SSH 私钥 | 完整的私钥内容（包括 BEGIN 和 END 行） |
| `SERVER_HOST` | 服务器 IP 地址或域名 | `120.26.41.79` |
| `SERVER_USER` | 服务器用户名 | `root` |

### 2. 获取 SSH 私钥

在本地运行以下命令获取 SSH 私钥内容：

```powershell
# Windows PowerShell
Get-Content $HOME\.ssh\id_rsa
```

或

```bash
# Linux/Mac
cat ~/.ssh/id_rsa
```

**重要提示**：
- 复制完整的私钥内容，包括 `-----BEGIN OPENSSH PRIVATE KEY-----` 和 `-----END OPENSSH PRIVATE KEY-----`
- 确保私钥格式正确，不要有多余的空格或换行

### 3. 配置示例

#### SSH_PRIVATE_KEY 示例：
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn
...（中间省略）...
AAAAAAEC
-----END OPENSSH PRIVATE KEY-----
```

#### SERVER_HOST 示例：
```
120.26.41.79
```

#### SERVER_USER 示例：
```
root
```

## 使用方法

### 自动部署

配置完成后，每次推送代码到 `main` 分支时，GitHub Actions 会自动执行以下步骤：

1. ✅ 检出代码
2. ✅ 安装 Node.js 和 pnpm
3. ✅ 安装项目依赖
4. ✅ 构建前端项目
5. ✅ 部署前端到服务器
6. ✅ 部署后端代码到服务器
7. ✅ 安装后端依赖并重启服务
8. ✅ 验证部署结果

### 手动触发部署

也可以在 GitHub 仓库页面手动触发部署：

1. 进入仓库页面
2. 点击 `Actions` 标签
3. 选择 `Deploy to Server` 工作流
4. 点击 `Run workflow` 按钮
5. 选择 `main` 分支并点击 `Run workflow`

## 查看部署日志

1. 进入仓库的 `Actions` 标签页
2. 点击最新的工作流运行记录
3. 查看每个步骤的详细日志
4. 如果部署失败，可以在日志中查看错误信息

## 本地部署（备用方案）

如果需要本地手动部署，可以使用项目根目录下的 `deploy.ps1` 脚本：

```powershell
.\deploy.ps1
```

## 注意事项

1. **SSH 密钥安全**：确保 SSH 私钥只添加到 GitHub Secrets 中，不要提交到代码仓库
2. **服务器权限**：确保 SSH 密钥对应的用户有权限访问部署目录
3. **首次部署**：首次使用 GitHub Actions 部署时，建议先手动触发测试
4. **部署失败**：如果部署失败，检查 Actions 日志中的错误信息

