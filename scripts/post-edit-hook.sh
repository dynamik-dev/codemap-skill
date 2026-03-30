#!/bin/bash
# Codemap post-tool-use hook
# Detects structural changes (new files/directories) and tells the agent to update the codemap.
# Automatically installed to .claude/hooks/codemap-hook.sh during `codemap init`.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only care about Write (new files) — Edit doesn't change structure
if [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Skip files inside .codemap/ itself to avoid infinite loops
if [[ "$FILE_PATH" == *"/.codemap/"* ]] || [[ "$FILE_PATH" == *"/CLAUDE.md" ]]; then
  exit 0
fi

# Skip common non-structural paths
SKIP_PATTERNS=(
  "node_modules" ".git/" "dist/" "build/" "__pycache__"
  ".next/" "target/" "vendor/" ".cache/" ".turbo/"
  "package-lock.json" "yarn.lock" "pnpm-lock.yaml"
)

for pattern in "${SKIP_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    exit 0
  fi
done

# Make path relative to project root
REL_PATH="${FILE_PATH#"$CWD"/}"

# Check if .codemap/ exists — if not, codemap hasn't been initialized
CODEMAP_DIR="$CWD/.codemap"
if [[ ! -d "$CODEMAP_DIR" ]]; then
  exit 0
fi

CLAUDE_MD="$CWD/CLAUDE.md"
if [[ ! -f "$CLAUDE_MD" ]]; then
  exit 0
fi

# Extract area paths from the CODEMAP table in CLAUDE.md
# Parses lines like: | Area Name | `src/api/` | description |
# Pulls out the path between backticks
AREA_PATHS=$(sed -n '/<CODEMAP>/,/<\/CODEMAP>/p' "$CLAUDE_MD" \
  | grep -oE '`[^`]+/`' \
  | tr -d '`' \
  || true)

if [[ -z "$AREA_PATHS" ]]; then
  exit 0
fi

# Find which area this file belongs to (longest matching prefix wins)
MATCHED_AREA=""
MATCHED_LEN=0
while IFS= read -r area_path; do
  # Normalize: strip trailing slash for prefix matching, then add it back
  area_prefix="${area_path%/}/"
  if [[ "$REL_PATH" == "$area_prefix"* ]]; then
    path_len=${#area_prefix}
    if (( path_len > MATCHED_LEN )); then
      MATCHED_AREA="$area_path"
      MATCHED_LEN=$path_len
    fi
  fi
done <<< "$AREA_PATHS"

if [[ -n "$MATCHED_AREA" ]]; then
  # File is in a known area — check if it's tracked in a sub-document
  SUBDOC=""
  for f in "$CODEMAP_DIR"/*.md; do
    if [[ -f "$f" ]] && grep -q "\`$MATCHED_AREA" "$f" 2>/dev/null; then
      SUBDOC="$f"
      break
    fi
  done

  if [[ -n "$SUBDOC" ]] && ! grep -q "$REL_PATH" "$SUBDOC" 2>/dev/null; then
    cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "CODEMAP_UPDATE_NEEDED: $REL_PATH was created in existing area '$MATCHED_AREA'. Update the sub-document at .codemap/$(basename "$SUBDOC") to include this file."
  }
}
HOOK_JSON
  fi
  exit 0
fi

# File doesn't match any known area — new area detected
# Find the most likely area path (parent directory of the new file, relative to root)
PARENT_DIR=$(dirname "$REL_PATH")
cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "CODEMAP_UPDATE_NEEDED: $REL_PATH was created outside any known codemap area. Nearest directory: '$PARENT_DIR/'. Consider adding it to the CODEMAP table in CLAUDE.md and generating a sub-document."
  }
}
HOOK_JSON
