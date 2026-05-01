#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "Repo: $ROOT_DIR"
echo "Shell: ${SHELL:-unknown}"

if [[ -r "$HOME/.zshenv" ]]; then
  if grep -n '\.cargo/env' "$HOME/.zshenv" >/dev/null 2>&1; then
    echo "warning: $HOME/.zshenv sources .cargo/env; make this conditional if macOS blocks the file."
  fi
fi

if [[ -r "$HOME/.profile" ]]; then
  if grep -n '\.cargo/env' "$HOME/.profile" >/dev/null 2>&1; then
    echo "warning: $HOME/.profile sources .cargo/env; make this conditional if macOS blocks the file."
  fi
fi

if ! touch .flutter_write_check 2>/dev/null; then
  echo "error: repo root is not writable by this terminal session" >&2
  exit 1
fi
rm -f .flutter_write_check

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter is not on PATH" >&2
  exit 127
fi

flutter_bin="$(command -v flutter)"
echo "Flutter: $flutter_bin"

if [[ ! -x "$flutter_bin" ]]; then
  echo "error: flutter binary is not executable" >&2
  exit 1
fi

flutter --version
flutter doctor -v

echo "Flutter environment doctor completed."
