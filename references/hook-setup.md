# Hook Setup Guide

The codemap post-tool-use hook automatically detects when new files are created and tells the agent to update the codemap. This keeps the codemap in sync without manual `codemap update` commands.

## What the Hook Does

After any `Write` tool use (new file creation), the hook:

1. Checks if a `.codemap/` directory exists (codemap has been initialized)
2. Determines whether the new file is in a known area or creates a new area
3. Outputs `CODEMAP_UPDATE_NEEDED` with instructions for the agent

The hook is lightweight — it skips generated directories, lock files, and changes to `.codemap/` itself (preventing loops).

## Installation

### 1. Copy the hook script to your project

```bash
mkdir -p .claude/hooks
cp /path/to/codemap-skill/scripts/post-edit-hook.sh .claude/hooks/codemap-hook.sh
chmod +x .claude/hooks/codemap-hook.sh
```

### 2. Add the hook to your project's `.claude/settings.json`

Create or edit `.claude/settings.json` in your project root:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/codemap-hook.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### 3. Verify

Create any new file with Claude and check that the agent receives the `CODEMAP_UPDATE_NEEDED` message and updates the codemap accordingly.

## Configuration Options

### Watch Edit operations too

If you want the hook to also fire on file edits (not just new files), change the matcher:

```json
"matcher": "Edit|Write"
```

Note: The hook script currently only acts on `Write` operations. To respond to `Edit` as well, modify the script to remove the `Write`-only check and add logic for detecting structural changes in edits.

### User-scoped installation

To enable the hook for all projects, add it to `~/.claude/settings.json` instead. Use an absolute path to the hook script:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/codemap-hook.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## How Hook Output Reaches the Agent

The hook outputs JSON with a `hookSpecificOutput.additionalContext` field. Claude Code feeds this context back to the agent as part of the tool result, so the agent sees the `CODEMAP_UPDATE_NEEDED` message and can act on it using the codemap skill's instructions.

## Troubleshooting

**Hook not firing:**
- Ensure the script is executable: `chmod +x .claude/hooks/codemap-hook.sh`
- Check that `jq` is installed (required for JSON parsing): `brew install jq` or `apt install jq`
- Verify the settings.json is in the right location (`.claude/settings.json` at project root)

**Infinite loops:**
- The hook skips changes to `.codemap/` and `CLAUDE.md` to prevent loops
- If you see repeated updates, check that the skip patterns are working

**No output from hook:**
- The hook only outputs when `.codemap/` exists (codemap initialized) and a structural change is detected
- Run `codemap init` first to initialize the codemap
