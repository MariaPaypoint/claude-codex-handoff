#!/bin/sh
# Codex session context size: last input_tokens and share of the window.
# Usage: codex-ctx.sh <session id>
f=$(ls ~/.codex/sessions/*/*/*/rollout-*"$1"*.jsonl 2>/dev/null | head -1)
[ -n "$f" ] || { echo "session $1 not found"; exit 1; }
w=$(grep -a -o '"model_context_window":[0-9]*' "$f" | tail -1 | cut -d: -f2)
c=$(grep -a -o '"last_token_usage":{"input_tokens":[0-9]*' "$f" | tail -1 | grep -o '[0-9]*$')
echo "$1: context $c of $w ($((c * 100 / w))%)"
