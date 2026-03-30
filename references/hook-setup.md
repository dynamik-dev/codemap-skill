# Hook Reference

The post-tool-use hook is **automatically installed** during `codemap init`. This document is a reference for how it works and how to customize it.

## What the Hook Does

After any `Write` tool use (new file creation), the hook:

1. Checks if a `.codemap/` directory exists (codemap has been initialized)
2. Determines whether the new file is in a known area or creates a new area
3. Outputs `CODEMAP_UPDATE_NEEDED` with instructions for the agent

The hook is lightweight — it skips generated directories, lock files, and changes to `.codemap/` itself (preventing loops).

## Installed Files

`codemap init` creates two files in the target project:

- `.claude/hooks/codemap-hook.sh` — the hook script
- `.claude/settings.json` — hook configuration (merged into existing config if present)

## How Hook Output Reaches the Agent

The hook outputs JSON with a `hookSpecificOutput.additionalContext` field. Claude Code feeds this context back to the agent as part of the tool result, so the agent sees the `CODEMAP_UPDATE_NEEDED` message and can act on it using the codemap skill's instructions.

## Customization

### Watch Edit operations too

Change the matcher in `.claude/settings.json`:

```json
"matcher": "Edit|Write"
```

Note: The hook script currently only acts on `Write` operations. To respond to `Edit` as well, modify the script to remove the `Write`-only check.

### User-scoped installation

To enable the hook for all projects, move the config to `~/.claude/settings.json` and use an absolute path to the hook script.

## Troubleshooting

**Hook not firing:**
- Ensure the script is executable: `chmod +x .claude/hooks/codemap-hook.sh`
- Check that `jq` is installed: `brew install jq` or `apt install jq`
- Verify `.claude/settings.json` is at the project root

**Infinite loops:**
- The hook skips changes to `.codemap/` and `CLAUDE.md` to prevent loops
- If you see repeated updates, check that the skip patterns are working

**No output from hook:**
- The hook only outputs when `.codemap/` exists and a structural change is detected
- Run `codemap init` first to initialize the codemap
