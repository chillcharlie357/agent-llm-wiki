---
name: llm-wiki
description: Initialize and maintain a lightweight Markdown LLM Wiki through conversation. Use when a user shares this repository and asks an agent to set up a wiki schema, import external documents or code repositories, migrate another agent's memory, inspect sources, or curate durable knowledge for Codex, Trae, OpenCode, Pi, or Claude Code.
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
- Never import credential stores, auth files, environment files, or an entire agent home directory.
- Preserve existing `AGENTS.md` content; initialization only appends a marked maintenance block.
- Keep the wiki useful without Obsidian, a database, embeddings, or a running service. Optional search tools may be added later.
