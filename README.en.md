# WeCom Gemini Bot (cc-connect + OpenCode)

[中文说明](README.md) · [Troubleshooting Notes (ZH)](docs/排查与踩坑记录.md) · [Templates](templates/)

Self-host a WeCom (Enterprise WeChat) AI bot powered by Google Gemini on a 1 GB RAM Debian 12 VPS, using **WeCom's official WebSocket long-connection mode**, **`cc-connect`**, and **`OpenCode`**.

## Highlights

- **No public domain or callback server required**: Uses WeCom's official WebSocket mode (`mode = "websocket"`).
- **Live model & session management**: Switch models (`/model`, `/model switch <index>`) and start clean sessions (`/new`) directly from WeCom chat.
- **Customizable persona & clean chat bubbles**: Inject personality via `AGENTS.md` (includes an example template), suppress intermediate thinking bubbles and footers via `[display]`, and avoid Markdown italics in chat bubbles.
- **Anti-lockout timeouts**: Short `idle_timeout_mins` and `max_turn_time_mins` prevent a stalled Free Tier request from blocking the queue for the default 2 hours.

## Architecture

```text
WeCom Mobile / Desktop Client
        │ (Official WebSocket long connection)
        ▼
VPS: cc-connect (systemd daemon)
        │ (Spawns CLI, manages sessions & timeouts)
        ▼
OpenCode CLI (loads work_dir/AGENTS.md & auth.json)
        │ (HTTPS API)
        ▼
Google Gemini API
```

## Quick Setup

1. **Install dependencies** on Debian 12 (recommended >= 1 GB RAM + 1 GB Swap):
   - Node.js 20+ and `npm install -g cc-connect`
   - OpenCode CLI (`~/.opencode/bin/opencode`)
2. **Place sanitized configs**:
   - Copy `templates/opencode/opencode.example.json` to `~/.config/opencode/opencode.json`
   - Copy `templates/opencode/auth.example.json` to `~/.local/share/opencode/auth.json` (`chmod 600`) and insert your Gemini API key
   - Optionally copy `templates/workspace/AGENTS.md` to `/root/agent-workspace/AGENTS.md`
   - Copy `templates/cc-connect/config.example.toml` to `~/.cc-connect/config.toml` (`chmod 600`) and fill in your WeCom `bot_id` and `bot_secret`
3. **Run as systemd service**:
   - Copy `templates/systemd/cc-connect.service` to `/etc/systemd/system/cc-connect.service`
   - Run `systemctl daemon-reload && systemctl enable --now cc-connect`
   - Verify with `bash scripts/healthcheck.sh`

## Important Lessons Learned

- **Avoid image-only models on Free Tier** (e.g., `*-image` with `limit: 0`): OpenCode may retry silently until the 2-hour default timeout unless `idle_timeout_mins` is lowered.
- **Session compaction inheritance**: When resuming a long OpenCode session that triggers `compaction`, OpenCode may reuse the older model attached to the parent message rather than the newly configured `--model`. Send `/new` to switch to a fresh session after changing models.
- **New vs. older Gemini project keys**: Newer AI Studio project keys may return `HTTP 404` for `gemini-2.5-flash` while supporting newer models like `gemini-3.5-flash-lite` or `gemini-4-hydrogen`.
- **Commands take no angle brackets**: Send `/model switch 21`, not `/model switch <21>`.

## Privacy & Security

- This repository contains **only documentation and placeholder templates**. No real API keys, tokens, bot secrets, server IPs, or personal data are included.
- `.gitignore` excludes `config.toml`, `auth.json`, `opencode.json`, `.env`, logs, and session databases by default. Always keep `allow_from` restricted to your own user ID if your WeCom workspace has other members.
