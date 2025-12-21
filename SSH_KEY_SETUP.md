# SSH 密钥免密登录配置指南

## 当前状态

✅ **SSH 密钥已生成**
- 私钥位置: `C:\Users\Administrator\.ssh\id_rsa`
- 公钥位置: `C:\Users\Administrator\.ssh\id_rsa.pub`

## 公钥内容

```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzTV/X8vuENpzV5Kl9fqn4PA+8haGkyHwu7Cc3Fe/+dSqa5pmY533VTsVEubh+3XwmnwoM5EjTcrAwtFy6xDNVfnEOPKZ2iyCsB8MIwSGJC6B7lI6g/AY2BmfE/uSnBjS4L9UN/RuSPGLPNrVLzsuKHIAZvaHsPm0club0FxZdGUOlKXtdD4N98TXHh+cnqoGzpXr3mIzFEhNCMlBkz9bbcmz+PRK+qwL4d3Cj6btJh4SXr3zATI+kp/xru1YQQckIXtj01ECe1CikmwJPdWSyNNge24nlbuE7At1QYLkRcdLHfkgUtfl2LxXt3nJjzpE5V84QKX1N6fa+LU3aVNIQ6eRStugPKf++zymYHv/0CqV4PAOkLeUGthn4g8ecnzM6J+Tj48KmnuKw14bp81LQyWlbOAq/VQoFhgUiStIoi9LneQBHpbwsh4RQnTYRVbaMr7lxig3rXes2MO9PMpsHbw8q/gxAaOQv8H5UpLqiI45JxITUaYQILoABWjr3ws/mnuUj17wa+NY/ECcejMt9zJvMYishjkJIN5VzS0+L5WF4+OtTke1DqUcZOsDD058JauOx2sdvSTAnuJ1JjrYChwHJtoVt6SMZuZ1DdJAqI15TTbgQyEEwl8QQX/hl9VLD6hDcXZv/MpUrAvD5BA3DIb3cA1nmtnGYNAVSKvJE1w== 2376354689@qq.com
```

## 配置步骤

### 方法一：使用 PowerShell 命令（推荐）

在 PowerShell 中执行以下命令，**当提示输入密码时，输入: `Aa1305784515`**

```powershell
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh root@120.26.41.79 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo '公钥已添加'"
```

### 方法二：手动配置

1. **SSH 登录服务器**：
   ```powershell
   ssh root@120.26.41.79
   ```
   输入密码: `Aa1305784515`

2. **登录后执行以下命令**：
   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzTV/X8vuENpzV5Kl9fqn4PA+8haGkyHwu7Cc3Fe/+dSqa5pmY533VTsVEubh+3XwmnwoM5EjTcrAwtFy6xDNVfnEOPKZ2iyCsB8MIwSGJC6B7lI6g/AY2BmfE/uSnBjS4L9UN/RuSPGLPNrVLzsuKHIAZvaHsPm0club0FxZdGUOlKXtdD4N98TXHh+cnqoGzpXr3mIzFEhNCMlBkz9bbcmz+PRK+qwL4d3Cj6btJh4SXr3zATI+kp/xru1YQQckIXtj01ECe1CikmwJPdWSyNNge24nlbuE7At1QYLkRcdLHfkgUtfl2LxXt3nJjzpE5V84QKX1N6fa+LU3aVNIQ6eRStugPKf++zymYHv/0CqV4PAOkLeUGthn4g8ecnzM6J+Tj48KmnuKw14bp81LQyWlbOAq/VQoFhgUiStIoi9LneQBHpbwsh4RQnTYRVbaMr7lxig3rXes2MO9PMpsHbw8q/gxAaOQv8H5UpLqiI45JxITUaYQILoABWjr3ws/mnuUj17wa+NY/ECcejMt9zJvMYishjkJIN5VzS0+L5WF4+OtTke1DqUcZOsDD058JauOx2sdvSTAnuJ1JjrYChwHJtoVt6SMZuZ1DdJAqI15TTbgQyEEwl8QQX/hl9VLD6hDcXZv/MpUrAvD5BA3DIb3cA1nmtnGYNAVSKvJE1w== 2376354689@qq.com' >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   exit
   ```

## 验证配置

配置完成后，测试免密登录：

```powershell
ssh -i $env:USERPROFILE\.ssh\id_rsa root@120.26.41.79 "echo '免密登录成功'"
```

如果成功，会显示 "免密登录成功"，且不需要输入密码。

## 配置成功后

配置好 SSH 密钥后，就可以使用自动化部署脚本了：

```powershell
.\deploy-ssh.ps1 -ServerIP "120.26.41.79" -SSHKeyPath "$env:USERPROFILE\.ssh\id_rsa"
```

## 服务器信息

- **IP**: 120.26.41.79
- **用户名**: root
- **密码**: Aa1305784515
- **端口**: 22

