#!/usr/bin/env bash
# BSW Project Template — macOS / Linux Bootstrap
# Usage: ./bootstrap.sh [--platform bsw-mcal-msp]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
if [ -d /srv/workspaces/_shared ]; then
    echo "[bootstrap] BSW Project Template — ELM server setup"
else
    echo "[bootstrap] BSW Project Template — macOS/Linux Setup"
fi

# ── Python check ──────────────────────────────────────────────────────────────
PYTHON=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        ver=$("$cmd" --version 2>&1 | grep -oE '3\.[0-9]+')
        minor=$(echo "$ver" | cut -d. -f2)
        if [ "${minor:-0}" -ge 8 ]; then
            PYTHON="$cmd"
            echo "[bootstrap] Found: $($cmd --version)"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo "[bootstrap] ERROR: Python 3.8+ is required."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  Install via: brew install python3"
    else
        echo "  Install via: sudo apt install python3  (Debian/Ubuntu)"
        echo "            or: sudo dnf install python3  (Fedora)"
    fi
    exit 1
fi

# ── Run setup.py ─────────────────────────────────────────────────────────────
echo "[bootstrap] Running setup.py..."
"$PYTHON" "$SCRIPT_DIR/setup.py" "$@"

echo ""
echo "[bootstrap] Next step — load tool PATHs in your shell:"
echo "    source $SCRIPT_DIR/env-setup.sh"
