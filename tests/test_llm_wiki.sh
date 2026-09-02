#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CLI="$REPO_ROOT/skills/llm-wiki/scripts/llm-wiki"
HOOK="$REPO_ROOT/skills/llm-wiki/scripts/llm-wiki-hook"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/llm-wiki-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_file() { [ -f "$1" ] || fail "missing file $1"; }
assert_dir() { [ -d "$1" ] || fail "missing directory $1"; }
assert_contains() { grep -Fq "$2" "$1" || fail "$1 does not contain $2"; }

vault="$TEST_ROOT/vault"
mkdir -p "$vault"
printf '# Existing project rules\n' > "$vault/AGENTS.md"
"$CLI" init --root "$vault" --name "Team Brain" --purpose "Shared project memory." --language "中文" --areas "systems,decisions" --fields "owners"
assert_file "$vault/LLM-WIKI.md"
assert_file "$vault/wiki/index.md"
assert_file "$vault/.llm-wiki/sources.tsv"
assert_contains "$vault/LLM-WIKI.md" 'Topic areas: systems,decisions.'
assert_contains "$vault/AGENTS.md" '# Existing project rules'
assert_contains "$vault/AGENTS.md" '<!-- LLM-WIKI:START -->'
assert_contains "$vault/AGENTS.md" 'wiki/memory/'
assert_contains "$vault/AGENTS.md" '.llm-wiki/private-inbox/'
printf 'custom index\n' > "$vault/wiki/index.md"
"$CLI" init --root "$vault" --name "Team Brain 2" --force >/dev/null
assert_contains "$vault/wiki/index.md" 'custom index'
assert_contains "$vault/LLM-WIKI.md" '# Team Brain 2 schema'
rm -rf "$vault/wiki/memory" "$vault/.llm-wiki/private-inbox"

printf '# External document\n' > "$TEST_ROOT/document.md"
"$CLI" import document "$TEST_ROOT/document.md" --root "$vault"
assert_file "$vault/raw/documents/document.md"
printf '# Traversal check\n' > "$TEST_ROOT/traversal.md"
"$CLI" import document "$TEST_ROOT/traversal.md" --root "$vault" --name '../outside.md'
assert_file "$vault/raw/documents/outside.md"
[ ! -e "$vault/raw/outside.md" ] || fail 'import name escaped its destination root'

repo="$TEST_ROOT/source-repo"
mkdir "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.com
git -C "$repo" config user.name test
printf 'const answer = 42;\n' > "$repo/index.js"
git -C "$repo" add index.js
git -C "$repo" commit -qm init
"$CLI" import repo "$repo" --root "$vault" --name sample-code
assert_file "$vault/raw/repositories/sample-code/index.js"
[ ! -e "$vault/raw/repositories/sample-code/.git" ] || fail 'repository history was imported'

memory="$TEST_ROOT/memory"
mkdir "$memory"
printf '# Memory\n' > "$memory/MEMORY.md"
printf 'SECRET=x\n' > "$memory/.env"
printf 'ignore\n' > "$memory/token.txt"
"$CLI" import memory "$memory" --root "$vault" --name agent-a
assert_file "$vault/raw/memories/agent-a/MEMORY.md"
[ ! -e "$vault/raw/memories/agent-a/.env" ] || fail '.env was imported'
[ ! -e "$vault/raw/memories/agent-a/token.txt" ] || fail 'unsupported memory file was imported'

status=$("$CLI" status --root "$vault")
printf '%s\n' "$status" | grep -q '^sources: 4$' || fail 'source count is not 4'

"$CLI" memory remember api-choice --root "$vault" --content 'Use the Responses API for new services.' --summary 'Project API choice' --topics 'project,decision'
assert_file "$vault/wiki/memory/api-choice.md"
assert_dir "$vault/.llm-wiki/private-inbox"
assert_contains "$vault/wiki/memory/api-choice.md" 'Use the Responses API for new services.'
if "$CLI" memory remember api-choice --root "$vault" --content duplicate >/dev/null 2>&1; then
  fail 'remember overwrote an existing memory'
fi
set +e
"$CLI" memory remember concurrent --root "$vault" --content alpha --summary alpha >/dev/null 2>&1 &
pid_a=$!
"$CLI" memory remember concurrent --root "$vault" --content beta --summary beta >/dev/null 2>&1 &
pid_b=$!
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e
[ $((status_a + status_b)) -ne 0 ] || fail 'both concurrent remember commands succeeded'
[ "$status_a" -eq 0 ] || [ "$status_b" -eq 0 ] || fail 'both concurrent remember commands failed'
assert_file "$vault/wiki/memory/concurrent.md"
created=$(sed -n 's/^created: //p' "$vault/wiki/memory/api-choice.md")
"$CLI" memory update api-choice --root "$vault" --content 'Use Responses API by default; keep Chat Completions for legacy services.'
assert_contains "$vault/wiki/memory/api-choice.md" 'keep Chat Completions for legacy services.'
assert_contains "$vault/wiki/memory/api-choice.md" 'summary: "Project API choice"'
assert_contains "$vault/wiki/memory/api-choice.md" 'topics: [project, decision]'
[ "$(sed -n 's/^created: //p' "$vault/wiki/memory/api-choice.md")" = "$created" ] || fail 'memory update changed the created date'
recall=$("$CLI" memory recall 'legacy services' --root "$vault")
printf '%s\n' "$recall" | grep -q 'api-choice' || fail 'memory recall missed an English query'
"$CLI" memory remember chinese-memory --root "$vault" --content '项目统一使用事件驱动架构。' --summary '架构决策'
recall_zh=$("$CLI" memory recall '项目应该使用什么事件驱动架构？' --root "$vault")
printf '%s\n' "$recall_zh" | grep -q 'chinese-memory' || fail 'memory recall missed a Chinese query'
large_file="$TEST_ROOT/large-memory.md"
head -c 200000 /dev/zero | tr '\0' x > "$large_file"
printf '\nneedle-at-end\n' >> "$large_file"
"$CLI" memory remember large-memory --root "$vault" --file "$large_file" --summary 'Large recall fixture' >/dev/null
limited_recall=$("$CLI" memory recall 'needle-at-end' --root "$vault" --max-bytes 4096)
[ "$(printf '%s' "$limited_recall" | wc -c | tr -d ' ')" -le 4300 ] || fail 'memory recall exceeded the byte budget'
printf '%s\n' "$limited_recall" | grep -q '[truncated at 4096 bytes]' || fail 'truncated recall was not marked'
list=$("$CLI" memory list --root "$vault")
printf '%s\n' "$list" | grep -q '^api-choice$' || fail 'memory list missed api-choice'

transcript="$TEST_ROOT/session.jsonl"
printf '{"role":"user","content":"remember this candidate","token":"secret-value"}\n' > "$transcript"
capture_disabled=$(printf '{"transcript_path":"%s"}\n' "$transcript" | LLM_WIKI_CLI="$CLI" LLM_WIKI_ROOT="$vault" "$HOOK" session-end)
printf '%s\n' "$capture_disabled" | grep -q 'capture disabled' || fail 'session capture was not opt-in'
[ "$(find "$vault/.llm-wiki/private-inbox" -type f ! -name .gitignore | wc -l | tr -d ' ')" -eq 0 ] || fail 'disabled hook captured a transcript'
hook_capture=$(printf '{"transcript_path":"%s"}\n' "$transcript" | LLM_WIKI_CAPTURE=1 LLM_WIKI_CLI="$CLI" LLM_WIKI_ROOT="$vault" "$HOOK" session-end)
inbox_relative=$(printf '%s\n' "$hook_capture" | sed -n 's/^Captured memory candidate: //p')
assert_file "$vault/$inbox_relative"
assert_contains "$vault/$inbox_relative" 'remember this candidate'
assert_contains "$vault/$inbox_relative" '[REDACTED]'
if grep -Fq 'secret-value' "$vault/$inbox_relative"; then fail 'hook capture persisted a secret'; fi
permissions=$(stat -f '%Lp' "$vault/$inbox_relative" 2>/dev/null || stat -c '%a' "$vault/$inbox_relative")
[ "$permissions" = 600 ] || fail "inbox permissions are $permissions, expected 600"
printf 'oversized' > "$TEST_ROOT/oversized.jsonl"
if LLM_WIKI_CAPTURE=1 LLM_WIKI_CAPTURE_MAX_BYTES=4 LLM_WIKI_TRANSCRIPT="$TEST_ROOT/oversized.jsonl" LLM_WIKI_CLI="$CLI" LLM_WIKI_ROOT="$vault" "$HOOK" session-end >/dev/null 2>&1; then
  fail 'hook captured an oversized transcript'
fi
hook_recall=$(printf '{"prompt":"Which legacy services use Chat Completions?"}\n' | LLM_WIKI_CLI="$CLI" LLM_WIKI_ROOT="$vault" "$HOOK" prompt)
printf '%s\n' "$hook_recall" | grep -q 'api-choice' || fail 'prompt hook did not recall memory'
"$CLI" memory remember escaped-json --root "$vault" --content 'zxqv-after-quote-9173' --summary 'JSON parser fixture' >/dev/null
quoted_hook_recall=$(printf '%s\n' '{"prompt":"unmatched-prefix \"quoted phrase\" zxqv-after-quote-9173"}' | LLM_WIKI_CLI="$CLI" LLM_WIKI_ROOT="$vault" "$HOOK" prompt)
printf '%s\n' "$quoted_hook_recall" | grep -q 'escaped-json' || fail 'prompt hook did not parse escaped JSON quotes'
status=$("$CLI" status --root "$vault")
printf '%s\n' "$status" | grep -q '^memories: 5$' || fail 'status memory count is not 5'
printf '%s\n' "$status" | grep -q '^inbox: 1$' || fail 'status inbox count is not 1'

install_home="$TEST_ROOT/home"
mkdir -p "$install_home"
HOME="$install_home" LLM_WIKI_BIN_DIR="$install_home/bin" LLM_WIKI_CODEX_SKILLS_DIR="$install_home/codex-skills" "$REPO_ROOT/install.sh" --harness codex
assert_file "$install_home/codex-skills/llm-wiki/SKILL.md"
assert_file "$install_home/bin/llm-wiki"
assert_file "$install_home/bin/llm-wiki-hook"
HOME="$install_home" LLM_WIKI_BIN_DIR="$install_home/bin" LLM_WIKI_CODEX_SKILLS_DIR="$install_home/codex-skills" "$REPO_ROOT/uninstall.sh" --harness codex
[ ! -e "$install_home/codex-skills/llm-wiki" ] || fail 'skill was not removed'
[ ! -e "$install_home/bin/llm-wiki" ] || fail 'command was not removed'
[ ! -e "$install_home/bin/llm-wiki-hook" ] || fail 'hook command was not removed'

mkdir -p "$install_home/bin"
printf '#!/bin/sh\necho unrelated\n' > "$install_home/bin/llm-wiki"
if HOME="$install_home" LLM_WIKI_BIN_DIR="$install_home/bin" LLM_WIKI_CODEX_SKILLS_DIR="$install_home/codex-skills" "$REPO_ROOT/install.sh" --harness codex --force >/dev/null 2>&1; then
  fail 'installer overwrote an unrelated command'
fi
assert_contains "$install_home/bin/llm-wiki" 'echo unrelated'

printf '%s\n' 'PASS: llm-wiki init, imports, memory lifecycle, hooks, install, and uninstall'
