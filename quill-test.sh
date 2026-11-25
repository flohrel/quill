#!/usr/bin/env bash
# Fused launcher for RISKY live checkpoints (keyboard-exclusive focus,
# fullscreen/top-layer surfaces, input grabs). Replaces the running shell,
# then auto-kills qs when the fuse expires — unless you press ENTER in this
# terminal to disarm and keep it running.
#
#   ./quill-test.sh [fuse-seconds]     default: 120
#
# Worst case with a locked screen: wait out the fuse, get your session back,
# fix the bug. Pair with the niri panic bind (Mod+Shift+Escape → pkill -x qs)
# for the zero-wait escape hatch.
set -euo pipefail

fuse="${1:-120}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pkill -x qs 2>/dev/null || true
sleep 0.3

# quill-launch.sh ends in `exec qs`, so the backgrounded child keeps one PID
# from bash through exec — $! is the live qs process.
"$here/quill-launch.sh" &
qs_pid=$!

echo "quill up (pid ${qs_pid}) — fuse armed: ${fuse}s."
echo "Press ENTER here to DISARM and keep quill running."

if read -r -t "$fuse"; then
    echo "Disarmed — quill keeps running."
else
    echo "FUSE FIRED — killing qs. Fix the issue, then relaunch with ./quill-launch.sh"
    kill "$qs_pid" 2>/dev/null || pkill -x qs || true
fi
