#!/usr/bin/env bash
# Format hook for agent-config.
# Reads the tool-call JSON on stdin, formats the file that was written, echoes
# the JSON back unchanged.
# Hook contract: {"tool_name":"Write","tool_input":{"file_path":"...","content":"..."}}
set -euo pipefail

INPUT_JSON="$(cat)"

passthrough() {
  printf '%s\n' "$INPUT_JSON"
  exit 0
}

FILE_PATH="$(printf '%s' "$INPUT_JSON" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
print(data.get("tool_input", {}).get("file_path", "") or "")
' 2>/dev/null || printf '')"

[ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ] && [ -w "$FILE_PATH" ] || passthrough

# Only rewrite files we can read as text. Anything with a NUL byte, anything
# that is not valid UTF-8, and anything oversized is left alone — a formatter
# that corrupts a PNG is far worse than one that skips a file.
python3 - "$FILE_PATH" <<'PY' 2>/dev/null || passthrough
import pathlib, sys
p = pathlib.Path(sys.argv[1])
if p.stat().st_size > 2_000_000:
    sys.exit(1)
data = p.read_bytes()
if b"\x00" in data:
    sys.exit(1)
try:
    data.decode("utf-8")
except UnicodeDecodeError:
    sys.exit(1)
PY

# Write through the existing inode. `mv` from a mktemp file would replace it and
# reset the mode to 0600, silently stripping the executable bit off scripts.
write_back() {
  cat "$1" > "$2"
}

# Trim trailing whitespace, end with exactly one newline.
# No `sed -i`: the in-place flag is spelled differently on BSD and GNU, and this
# hook also runs on the Linux hosts.
# LC_ALL=C keeps sed byte-oriented: a file with invalid UTF-8 must not abort the
# hook. Bytes, not text, for the same reason.
trim_trailing_ws() {
  local target="$1" tmp
  tmp="$(mktemp)"
  if ! LC_ALL=C sed 's/[[:space:]]*$//' "$target" > "$tmp" 2>/dev/null \
     || ! python3 - "$tmp" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_bytes(p.read_bytes().rstrip(b"\n") + b"\n")
PY
  then
    rm -f "$tmp"
    return 1
  fi
  write_back "$tmp" "$target"
  rm -f "$tmp"
}

case "${FILE_PATH##*.}" in
  js|jsx|ts|tsx|json)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write "$FILE_PATH" >/dev/null 2>&1 || true
    else
      trim_trailing_ws "$FILE_PATH" || passthrough
    fi
    ;;
  *)
    trim_trailing_ws "$FILE_PATH" || passthrough
    ;;
esac

printf '%s\n' "$INPUT_JSON"
