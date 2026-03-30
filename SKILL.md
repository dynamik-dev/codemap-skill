---
name: codemap-skill
description: Generates and maintains a layered codemap (table of contents) for large codebases, enabling agents to navigate efficiently without flooding context windows. Use when user says "codemap init", "generate codemap", "map this codebase", "codemap update", or when hook output contains "CODEMAP_UPDATE_NEEDED".
tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
  - Agent
---

# Codemap

Generates a layered table of contents for a codebase so agents can navigate large projects without reading every file upfront.

## Instructions

### Layered Discovery Model

This skill uses a two-layer approach to codebase navigation:

- **Layer 0 (Always in context)**: A `<CODEMAP>` block in CLAUDE.md containing a compact table of major areas with 1-line descriptions. Agents always know WHERE to look.
- **Layer 1 (On-demand)**: Detailed sub-documents in `.codemap/` that break down each area with key files, patterns, and conventions. Agents read these when they need to work in a specific area.
- **Layer 2 (Source code)**: The actual files. Agents read these only when making changes.

The `<CODEMAP>` block is the entry point. It tells the agent what exists and where. The agent drills into `.codemap/` sub-documents only when it needs deeper context for a specific area.

### `codemap init` -- Generate Initial Codemap

1. **Scan the project structure.** Run `ls` at the project root. Use `Glob` to understand what's inside each top-level directory. Identify the major areas of the codebase.

2. **Identify major areas.** Group related directories into 5-15 logical areas. For each area, read 2-3 representative files to understand its purpose. Focus on what a developer would need to know to navigate — not implementation details.

3. **Determine area descriptions.** Each description must be specific and useful. Good: "REST endpoints for user management, billing, and webhook ingestion." Bad: "API stuff." Include the key domains or responsibilities contained in each area.

4. **Write the top-level codemap.** Insert a `<CODEMAP>` block into the project's CLAUDE.md. If CLAUDE.md does not exist, create it. If it already has content, append the codemap block — never overwrite existing content.

   Use this exact format:

   ```
   <CODEMAP>
   # Codemap

   | Area | Path | Description |
   |------|------|-------------|
   | {Area Name} | `{path}/` | {1-line description of what's here} |

   Sub-maps: `.codemap/` — read the relevant file before working in an unfamiliar area.
   </CODEMAP>
   ```

5. **Generate sub-documents.** For each area in the top-level table, create `.codemap/{area-slug}.md` with this structure:

   ```markdown
   # {Area Name} — `{path}/`

   {2-3 sentence overview of this area's responsibility and role in the system.}

   ## Structure

   | Path | Purpose |
   |------|---------|
   | `{relative-path}` | {what this file or subdirectory does} |

   ## Key Concepts
   - {important patterns, naming conventions, or architectural decisions}
   - {relationships to other areas}

   ## Entry Points
   - {main files a developer would start reading to understand this area}
   ```

   Sub-documents should be 50-150 lines. If an area is very large, split it into sub-areas and note that in the parent sub-document.

6. **Handle large projects.** If the project has more than 15 top-level areas, group related areas under headings in the codemap table. For example, group all `src/features/*` under a single "Features" area, with each feature getting its own sub-document.

7. **Add `.codemap/` to `.gitignore`** unless the user explicitly wants to track it. The codemap is a generated artifact that can be regenerated.

### `codemap update` -- Refresh the Codemap

1. Read the existing `<CODEMAP>` block from CLAUDE.md.
2. Scan the current project structure.
3. Compare against the codemap:
   - **New directories** not in the codemap: add to the table, generate sub-documents.
   - **Removed directories**: remove from the table, delete orphaned sub-documents.
   - **Changed areas** (new or removed files): update the relevant sub-document.
4. Do not reorganize areas that have not changed. Preserve existing descriptions unless they are now inaccurate.

### Hook-Triggered Updates

When the post-tool-use hook detects a structural change, it outputs `CODEMAP_UPDATE_NEEDED` with the affected path. Handle this with a lightweight update:

1. Parse the hook output to identify the affected file path.
2. Determine which codemap area the file belongs to.
3. If it belongs to an existing area: update only that area's sub-document in `.codemap/`.
4. If it creates a new top-level area: add a row to the `<CODEMAP>` table and generate a new sub-document.
5. Do NOT do a full rescan. Only update what changed.

## Constraints

- The `<CODEMAP>` block must stay compact: max ~30 lines. Agents read this on every invocation.
- Never modify content outside the `<CODEMAP>` tags in CLAUDE.md. Other content in CLAUDE.md belongs to the user.
- Use relative paths from the project root in all codemap entries.
- Exclude generated/dependency directories: `node_modules/`, `.git/`, `dist/`, `build/`, `__pycache__/`, `vendor/`, `.next/`, `target/`, etc.
- Do not list individual files in the top-level table — only directories or logical groups of directories.
- Descriptions must be specific enough to help an agent decide whether to drill into that area. Generic labels like "utilities" or "helpers" must include what kind.
- Sub-documents must list actual files, not just directory names. An agent reading a sub-document should know exactly what each file does without opening it.

## Examples

### Example 1: Init on a Next.js app

**Input:**
```
user: codemap init
```

**Expected output in CLAUDE.md:**

```
<CODEMAP>
# Codemap

| Area | Path | Description |
|------|------|-------------|
| App Routes | `app/` | Next.js App Router pages: dashboard, auth flows, settings, and public marketing pages |
| API Routes | `app/api/` | REST endpoints for users CRUD, Stripe webhooks, file uploads, and team invitations |
| Components | `components/` | React components: ui primitives (Button, Modal, Input), feature widgets (UserCard, PlanSelector), and layout shells |
| Database | `prisma/` | Prisma schema with User, Team, Subscription, and Invoice models; migrations and seed scripts |
| Auth | `lib/auth/` | NextAuth.js config with Google and GitHub providers, session helpers, role-based access checks |
| Server Actions | `lib/actions/` | Form handlers for profile updates, team management, billing operations |
| Utilities | `lib/utils/` | Date formatters, currency helpers, Zod validation schemas, shared TypeScript types |
| Config | `.` (root) | next.config.js, tailwind.config.ts, tsconfig.json, environment variable schemas |

Sub-maps: `.codemap/` — read the relevant file before working in an unfamiliar area.
</CODEMAP>
```

**Expected sub-document `.codemap/api-routes.md`:**

```markdown
# API Routes — `app/api/`

REST API layer handling external integrations, user-facing CRUD operations, and webhook ingestion. All routes use Next.js Route Handlers with middleware for auth and rate limiting.

## Structure

| Path | Purpose |
|------|---------|
| `users/route.ts` | User CRUD — list, create, update, delete with pagination |
| `users/[id]/route.ts` | Single user operations — get, patch, delete by ID |
| `webhooks/stripe/route.ts` | Stripe webhook handler — subscription lifecycle events |
| `uploads/route.ts` | File upload to S3 with presigned URLs |
| `teams/route.ts` | Team management — create, list, invite members |
| `teams/[id]/members/route.ts` | Team member operations — add, remove, change role |

## Key Concepts
- All routes validate input with Zod schemas from `lib/utils/schemas.ts`
- Auth middleware applied via `lib/auth/middleware.ts` — checks session + role
- Stripe webhook route skips auth but validates webhook signature
- Error responses follow `{ error: string, code: string }` shape

## Entry Points
- `users/route.ts` — simplest CRUD example, good starting point for API patterns
- `webhooks/stripe/route.ts` — shows webhook signature validation pattern
```

### Example 2: Hook-triggered update

**Hook output:**
```
CODEMAP_UPDATE_NEEDED: src/services/notifications.ts was created
```

**Expected behavior:**
Agent checks if `src/services/` is in the codemap. If yes, adds `notifications.ts` to `.codemap/services.md`. If `src/services/` is a new area, adds a row to the `<CODEMAP>` table and creates `.codemap/services.md`.

### Example 3: Update after refactoring

**Input:**
```
user: codemap update
```

**Expected behavior:**
Agent diffs the current directory structure against the existing codemap. Adds new areas, removes deleted ones, refreshes sub-documents for changed areas. Does not touch unchanged areas.

## References

- `references/hook-setup.md` — Instructions for configuring the post-tool-use hook in Claude Code settings
