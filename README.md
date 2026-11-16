# 企业微信 Gemini 智能机器人（cc-connect + OpenCode）

[English](README.en.md) · [排查与踩坑记录](docs/排查与踩坑记录.md) · [配置模板](templates/)

在 1 GB 内存的轻量 Debian VPS 上，利用 **企业微信智能机器人官方 WebSocket 长连接** + **`cc-connect`** + **`OpenCode`** 接入 Google Gemini API，实现手机与电脑端企业微信随时私聊 AI。

**特点：**
- **无需公网域名与备案回调**：采用企业微信 API 模式长连接（`websocket`），只要 VPS 能连外网即可双向通信。
- **无痛切换模型与会话**：在微信聊天窗口直接发送 `/model`、`/model switch <序号>`、`/new` 管理模型与会话。
- **可自定义机器人性格与去 AI 味**：通过工作区 `AGENTS.md` 注入人格设定（附带傲娇大小姐风猫娘女仆模板）、隐藏英文思考气泡与底部状态栏，并强制纯正体自然口语输出。
- **防卡死超时保护**：针对免费层级模型偶发限流/高负载的问题，配置了短空闲超时，避免单条出错消息锁死整个对话队列。

---

## 架构链路

```text
手机 / 电脑企业微信
        │ (官方 WebSocket 长连接，无需域名/反向代理)
        ▼
VPS: cc-connect (systemd 常驻守护进程)
        │ (调用本地 CLI 并管理会话与超时)
        ▼
OpenCode CLI (读取工作区 AGENTS.md 人格与 auth.json)
        │ (HTTPS API)
        ▼
Google Gemini API (Free Tier / Pay-as-you-go)
```

---

## 环境准备

- **VPS**：Debian 12（建议至少 **1 GB 内存 + 1 GB Swap**；实测 512 MB 内存会频繁触发 Swap 抖动导致回复超过 3 分钟）
- **Node.js**：v20+（供 `cc-connect` 安装运行）
- **企业微信**：任意个人可创建的企业微信空间 → 工作台 → 智能机器人 → **API 模式 → 使用长连接**
- **Google Gemini API Key**：从 [Google AI Studio](https://aistudio.google.com/) 申请

---

## 快速搭建步骤

### 1. 安装 `cc-connect` 与 `OpenCode`

```bash
# 安装 cc-connect（示例版本 v1.4.1）
npm install -g cc-connect

# 安装 OpenCode CLI（参考官方安装脚本后确认二进制路径，通常位于 ~/.opencode/bin/opencode）
curl -fsSL https://opencode.ai/install | bash
```

### 2. 创建工作区并配置模型与 API Key

```bash
mkdir -p /root/agent-workspace
mkdir -p /root/.config/opencode
mkdir -p /root/.local/share/opencode
mkdir -p /root/.cc-connect/logs
```

1. 将本仓库 `templates/opencode/opencode.example.json` 复制到 `/root/.config/opencode/opencode.json`。
2. 将本仓库 `templates/opencode/auth.example.json` 复制到 `/root/.local/share/opencode/auth.json`，填入你的 Gemini API Key，并收紧权限：
   ```bash
   chmod 600 /root/.local/share/opencode/auth.json
   ```
3. *(可选)* 若希望自定义机器人性格，将 `templates/workspace/AGENTS.md` 复制到 `/root/agent-workspace/AGENTS.md` 并按需修改人设。

### 3. 在企业微信后台创建长连接机器人

1. 进入企业微信管理台或客户端「工作台 → 智能机器人 → 创建机器人」。
2. 选择 **API 模式**，连接方式勾选 **使用长连接**（无需填写回调 URL）。
3. 复制页面生成的 **Bot ID** 与 **Secret**。
4. 如仅限自己使用，建议在「使用方式」中仅对自己可见，或在配置中设置白名单。

### 4. 配置 `cc-connect` 与 `systemd` 常驻

1. 将 `templates/cc-connect/config.example.toml` 复制到 `/root/.cc-connect/config.toml`（权限建议 `chmod 600 /root/.cc-connect/config.toml`），填入你的 `bot_id` 与 `bot_secret`。
   - **重要**：`idle_timeout_mins = 5`、`max_turn_time_mins = 15` 必须放在 `[[projects]]` 之前的顶层区域（不可放到 `[display]` 后面）。
   - 修改 `config.toml` 或重设会话前，请先 `systemctl stop cc-connect`，避免进程退出时用内存旧状态覆盖磁盘。
2. 将 `templates/systemd/cc-connect.service` 复制到 `/etc/systemd/system/cc-connect.service` 并启动：
   ```bash
   systemctl daemon-reload
   systemctl enable --now cc-connect
   ```
3. 运行本仓库提供的只读检查脚本确认长连接订阅成功：
   ```bash
   bash scripts/healthcheck.sh
   ```
   日志中出现 `wecom-ws: subscribed successfully` 即代表已连通。

---

## 常用微信端斜杠指令

| 指令 | 作用 | 注意事项 |
|---|---|---|
| `/model` | 列出当前可用模型及编号 | — |
| `/model switch 21` | 切换模型（按序号或完整模型名） | **不要带尖括号 `< >`**，也不要直接发纯数字 |
| `/new` | 开启一个全新的干净会话 | 更换人设或切换兼容模型后建议发送一次 |
| `/list` / `/switch` | 查看或切换历史会话 | — |

---

## 隐私与安全说明

- **本仓库仅包含教程说明与完全脱敏后的配置模板**，不包含任何个人 API Key、Token、企业微信 `Bot ID` / `Secret`、服务器 IP 或真实账号数据。
- `.gitignore` 已默认排除 `config.toml`、`auth.json`、`opencode.json`、`.env`、日志与数据库文件；如你 fork 本仓库，请同样**切勿将真实密钥提交到公开分支**。
- 在企业微信后台「使用方式」选为「多人使用」且服务端配置 `allow_from = "*"` 时，任何能接触该机器人的成员都可以调用代理并访问工作区目录；个人自用强烈建议限制为仅本人可见并配置具体的 `allow_from` UserID。

## 验证范围与已知局限

- 本方案已在 Debian 12（1 GB RAM + 1 GB Swap）、`cc-connect v1.4.1`、`OpenCode 1.17.13` 环境下完成端到端真实对话验证。
- 免费层级（Free Tier）模型列表与限流策略会随 Google AI Studio 调整而变化；新老项目 Key 支持的模型并不完全一致，高峰期高负载模型可能出现 `503` 或耗时延长。
- 更多实操排坑细节见 [docs/排查与踩坑记录.md](docs/排查与踩坑记录.md)。
