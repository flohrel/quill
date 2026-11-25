#!/usr/bin/env bash
# Launches quill: make the locally-built Niri plugin importable, then run qs.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# build/qml is on QML_IMPORT_PATH only so the vendored Niri plugin (build/qml/Niri)
# is importable. A stale copy of the qs.* source modules under build/qml/qs would
# SHADOW the live source — qs.config/qs.bar/etc. would resolve to the snapshot
# instead of the repo, silently serving stale code. Only Niri belongs here.
rm -rf "${here}/build/qml/qs"
export QML_IMPORT_PATH="${here}/build/qml${QML_IMPORT_PATH:+:${QML_IMPORT_PATH}}"
exec qs -c "${here}"
