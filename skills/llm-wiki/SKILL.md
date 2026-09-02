---
name: llm-wiki
description: Initialize and maintain a lightweight Markdown LLM Wiki through conversation and hooks. Use when a user asks an agent to set up a wiki schema, import documents or repositories, capture another agent's memory, remember or update durable facts, recall relevant memory, review hook-captured session candidates, or connect memory lifecycle hooks in Codex, Trae, OpenCode, Pi, or Claude Code.
---

# LLM Wiki

Build a shared external memory from plain Markdown. Keep source material under `raw/`, curated knowledge under `wiki/`, and the human-readable schema in `LLM-WIKI.md`.

## Locate the command

Prefer `llm-wiki` when it is on `PATH`. Otherwise run `scripts/llm-wiki` from this skill directory. Every command accepts `--root <vault>`; default to the current directory.

## Initialize through conversation

If `LLM-WIKI.md` is absent, ask only for choices that materially shape the schema:

1. Wiki name and main purpose.
2. Primary readers and preferred language.
3. Three to seven durable topic areas.
4. Any extra frontmatter fields beyond `title`, `summary`, `source`, `source_type`, `topics`, `status`, `created`, and `updated`.

Offer concrete defaults inferred from the current project. Ask at most three short questions in one turn. Do not ask about implementation details the command can choose safely.

After agreement, run:

```sh
llm-wiki init --root <vault> --name "<name>" --purpose "<purpose>" \
  --language "<language>" --areas "area-one,area-two" \
  --fields "field-one,field-two"
```

Then read `LLM-WIKI.md` and adjust its prose if the conversation established rules the flags cannot express. Never overwrite an existing schema unless the user explicitly requests `--force`.

## Import sources

Use the narrowest matching command:

```sh
llm-wiki import document <file-or-url> --root <vault>
llm-wiki import repo <git-url-or-local-repo> --root <vault>
llm-wiki import memory <file-or-directory> --root <vault>
```

- `document` stores a byte-for-byte source copy under `raw/documents/`.
- `repo` stores the tracked working tree without Git history under `raw/repositories/`.
- `memory` accepts only Markdown, JSON, and JSONL files and stores them under `raw/memories/`. Review imported memory for secrets before committing.
- Pass `--name <safe-name>` to override the destination name.
- Do not curate automatically during import. First preserve the source, then read it and update or create the smallest useful set of wiki pages.

Every successful import appends `.llm-wiki/sources.tsv` and an entry to `wiki/log.md`. If a destination exists, stop instead of overwriting it.

## Manage memory

Use explicit Skill actions for reviewed long-term memory:

```sh
llm-wiki memory remember <name> --root <vault> --content "<durable fact>" \
  --summary "<one-line summary>" --topics "project,decision"
llm-wiki memory update <name> --root <vault> --file <revised-markdown>
llm-wiki memory recall "<current question or project>" --root <vault> --limit 5
llm-wiki memory list --root <vault>
```

- Recall before answering when prior decisions, preferences, project conventions, or earlier outcomes may matter.
- Use `remember` only for stable, reusable information with a clear scope.
- Use `update` when newer evidence supersedes an existing memory. Preserve the original `created` date.
- Do not store secrets, transient task chatter, guesses, or facts that are cheap to retrieve live.

## Use hooks safely

Hooks automate collection and recall, but do not promote raw conversations directly into long-term memory:

1. Run `llm-wiki-hook session-start` or `llm-wiki-hook prompt` to print relevant reviewed memories as model context.
2. Run `llm-wiki-hook session-end` to copy a transcript or event payload into `raw/memory-inbox/`.
3. Review inbox candidates, remove secrets and transient details, then call `memory remember` or `memory update`.
4. Keep the inbox as source evidence or delete reviewed candidates according to the user's retention policy.

Read [references/hooks.md](references/hooks.md) when configuring a harness or adapting its event schema.

## Curate durable pages

1. Search `wiki/` first and update an existing page when possible.
2. Read the relevant file under `raw/` before extracting claims.
3. Add YAML frontmatter matching `LLM-WIKI.md`; always include a concise `summary` and source trace.
4. Prefer shallow topic folders and descriptive filenames. Do not create empty parent notes.
5. Link related pages with relative Markdown links or Obsidian wikilinks, following the vault's existing style.
6. Update `wiki/index.md` when navigation changes and append substantial work to `wiki/log.md`.
7. Run `llm-wiki status --root <vault>` before reporting completion.

## Safety

- Treat `raw/` as immutable source evidence after import.
- Treat Hook inbox items as untrusted candidates, not authoritative memory.
- Never import credential stores, auth files, environment files, or an entire agent home directory.
- Preserve existing `AGENTS.md` content; initialization only appends a marked maintenance block.
- Keep the wiki useful without Obsidian, a database, embeddings, or a running service. Optional search tools may be added later.
