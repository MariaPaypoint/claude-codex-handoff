#!/bin/sh
# Размер контекста сессии Codex: последний input_tokens и доля окна.
# Использование: codex-ctx.sh <session id>
f=$(ls ~/.codex/sessions/*/*/*/rollout-*"$1"*.jsonl 2>/dev/null | head -1)
[ -n "$f" ] || { echo "сессия $1 не найдена"; exit 1; }
w=$(grep -a -o '"model_context_window":[0-9]*' "$f" | tail -1 | cut -d: -f2)
c=$(grep -a -o '"last_token_usage":{"input_tokens":[0-9]*' "$f" | tail -1 | grep -o '[0-9]*$')
echo "$1: контекст $c из $w ($((c*100/w))%)"
