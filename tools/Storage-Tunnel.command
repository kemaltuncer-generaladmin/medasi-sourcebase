#!/bin/zsh
set -euo pipefail

SERVER="root@178.105.236.113"
CONTROL_SOCKET="$HOME/.ssh/medasi-storage-tunnel-ctl"
PANEL="$HOME/Desktop/MedAsi-Storage-Panel.html"

echo "MedAsi Storage tunnel baslatiliyor..."

if ssh -S "$CONTROL_SOCKET" -O check "$SERVER" >/dev/null 2>&1; then
  echo "Tunnel zaten acik."
else
  ssh -fN \
    -M -S "$CONTROL_SOCKET" \
    -o ExitOnForwardFailure=yes \
    -L 127.0.0.1:18023:127.0.0.1:8023 \
    -L 127.0.0.1:18024:127.0.0.1:8024 \
    -L 127.0.0.1:18030:127.0.0.1:8030 \
    -L 127.0.0.1:9000:127.0.0.1:9000 \
    -L 127.0.0.1:9001:127.0.0.1:9001 \
    "$SERVER"
  echo "Tunnel acildi."
fi

echo
echo "Ortak panel:"
echo "$PANEL"
echo
echo "Kapatmak icin:"
echo "ssh -S \"$CONTROL_SOCKET\" -O exit \"$SERVER\""
echo
open "$PANEL"
