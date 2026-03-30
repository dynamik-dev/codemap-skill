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

# Get the top-level directory of the changed file (relative to project root)
TOP_DIR=$(echo "$REL_PATH" | cut -d'/' -f1)

# Check if this top-level area is already tracked in the codemap
CLAUDE_MD="$CWD/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]]; then
  if grep -q "\`$TOP_DIR/" "$CLAUDE_MD" 2>/dev/null; then
    # Area exists — check if the specific file is tracked in the sub-document
    AREA_SLUG=$(echo "$TOP_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Find matching sub-document
    SUBDOC=""
    for f in "$CODEMAP_DIR"/*.md; do
      if [[ -f "$f" ]] && grep -q "\`$TOP_DIR/" "$f" 2>/dev/null; then
        SUBDOC="$f"
        break
      fi
    done

    if [[ -n "$SUBDOC" ]] && ! grep -q "$REL_PATH" "$SUBDOC" 2>/dev/null; then
      # File is in a known area but not listed in the sub-document
      cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "CODEMAP_UPDATE_NEEDED: $REL_PATH was created in existing area '$TOP_DIR'. Update the sub-document at .codemap/$(basename "$SUBDOC") to include this file."
  }
}
HOOK_JSON
      exit 0
    fi

    # File already tracked or sub-document not found — no action needed
    exit 0
  fi
fi

# New top-level area detected
cat <<HOOK_JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "CODEMAP_UPDATE_NEEDED: $REL_PATH was created in a new area '$TOP_DIR'. Add '$TOP_DIR' to the CODEMAP table in CLAUDE.md and generate a new sub-document at .codemap/${TOP_DIR}.md."
  }
}
HOOK_JSON
