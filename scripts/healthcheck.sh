#!/usr/bin/env bash
# 只读排查脚本：检查 cc-connect 服务、内存、残留进程与最近日志（自动脱敏 bot_id）
set -euo pipefail

echo "=== 1. 内存与负载 ==="
free -h
uptime

echo ""
echo "=== 2. systemd 服务状态 ==="
systemctl status cc-connect --no-pager -l | head -n 20 || true

echo ""
echo "=== 3. 当前相关进程 ==="
ps aux | grep -iE 'cc-connect|opencode' | grep -v grep || true

echo ""
echo "=== 4. 最近 20 条 cc-connect 日志（已脱敏） ==="
if [ -f /root/.cc-connect/logs/cc-connect.log ]; then
  tail -n 20 /root/.cc-connect/logs/cc-connect.log | sed -E 's/bot_id=[^ ]+/bot_id=***REDACTED***/g'
else
  echo "(未找到 /root/.cc-connect/logs/cc-connect.log)"
fi
