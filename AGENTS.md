# AGENTS.md

## Project

MarketLab is a fake-money Yes/No market app for a 2-hour Cursor workshop.

Keep changes small, clear, teachable, and easy to review.

## Stack

Use the existing stack:

- Next.js App Router
- React Server Components by default
- Server Actions for data changes
- Supabase Auth and Database
- Bun, TypeScript, Tailwind CSS, Biome, Vitest, and Task

Do not add dependencies or replace the stack unless asked.

## Skills and Docs

Project skills live in `.agents/skills/` and are pinned in `skills-lock.json`. Use them for framework-specific work (Supabase, Next.js App Router, React, Postgres, UI).

To add or update skills: `npx skills add <owner/repo@skill>`. Browse options at [skills.sh](https://skills.sh/).

For Next.js-specific uncertainty, prefer the installed docs in `node_modules/next/dist/docs/`.

## Project Map

- `src/app/`: routes, layouts, and global styles
- `src/components/`: reusable UI components
- `src/lib/`: shared utilities and Supabase clients
- `supabase/`: migrations, config, and seed data
- `Taskfile.yml`: project commands

## Commands

Use `task` when a task exists.

- Setup: `task setup`
- Dev server: `task dev`
- Check formatting/linting: `task check`
- Typecheck: `task typecheck`
- Run tests once: `task test:run`
- Full verification: `task verify`
- Supabase login: `task db:login`
- Link hosted project: `task db:link`
- Apply migrations and seed: `task db:push`
- Generate DB types: `task db:types`
- List commands: `task --list`

If `task` is unavailable, activate mise in the current shell, then retry the `task` command. Do not use `mise exec -- task`.

## How to Work

- Build one small feature slice at a time.
- Reuse existing components and utilities before creating new ones.
- Add focused Vitest tests for important logic.
- Run the smallest useful check while iterating, and finish with `task verify` when practical.
- Explain the important diff and any remaining risk.

## Supabase Rules

- Migrations are the schema source of truth.
- Every Server Action must verify authentication and authorization before mutating data.
- Prefer RLS and Supabase RPC functions for balance-changing operations.
- Public market data may be readable.
- Profiles, positions, and ledger entries must stay owner-scoped.
- After changing migrations or seed data, run `task db:push` and `task db:types` once the repo is linked to Supabase.

### Migration Safety

- Create exactly one migration file per schema change.
- Run `supabase migration new <name>` only once. Do not retry if the CLI hangs, stalls, or errors.
- Verify the new migration file is non-empty before writing SQL.
- Do not manually invent another timestamped migration filename.
- If the CLI fails or produces an empty migration file, stop and report the issue instead of creating a second migration file.
- Before `task db:push`, confirm there is only one new migration file in `supabase/migrations/`.
- Do not leave zero-byte `.sql` files in `supabase/migrations/`.
- After pushing, confirm local and remote migration history match: `supabase migration list --linked`.

### Supabase Verification

Once the repo is linked to a hosted Supabase project:

```bash
task db:push
task db:types
supabase migration list --linked
```

`task db:push` applies migrations and seed data. `task db:types` writes `src/lib/supabase/database.types.ts`.

## Validation

- Code changes: run `task verify` when practical.
- Hook changes: run `task hooks:validate` and `task hooks:run`.
- If a required check cannot run, report why and what risk remains.
