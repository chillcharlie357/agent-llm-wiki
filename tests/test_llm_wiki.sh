#!/bin/sh
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CLI="$REPO_ROOT/skills/llm-wiki/scripts/llm-wiki"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/llm-wiki-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_file() { [ -f "$1" ] || fail "missing file $1"; }
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
printf 'custom index\n' > "$vault/wiki/index.md"
"$CLI" init --root "$vault" --name "Team Brain 2" --force >/dev/null
assert_contains "$vault/wiki/index.md" 'custom index'
assert_contains "$vault/LLM-WIKI.md" '# Team Brain 2 schema'

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

install_home="$TEST_ROOT/home"
mkdir -p "$install_home"
HOME="$install_home" LLM_WIKI_BIN_DIR="$install_home/bin" LLM_WIKI_CODEX_SKILLS_DIR="$install_home/codex-skills" "$REPO_ROOT/install.sh" --harness codex
assert_file "$install_home/codex-skills/llm-wiki/SKILL.md"
assert_file "$install_home/bin/llm-wiki"
HOME="$install_home" LLM_WIKI_BIN_DIR="$install_home/bin" LLM_WIKI_CODEX_SKILLS_DIR="$install_home/codex-skills" "$REPO_ROOT/uninstall.sh" --harness codex
[ ! -e "$install_home/codex-skills/llm-wiki" ] || fail 'skill was not removed'
[ ! -e "$install_home/bin/llm-wiki" ] || fail 'command was not removed'

mkdir -p "$install_home/bin"
printf '#!/bin/sh\necho unrelated\n' > "$install_home/bin/llm-wiki"
if HOME="$install_home" LLM_WIKI_BIN_DIR="$install_home/bin" LLM_WIKI_CODEX_SKILLS_DIR="$install_home/codex-skills" "$REPO_ROOT/install.sh" --harness codex --force >/dev/null 2>&1; then
  fail 'installer overwrote an unrelated command'
fi
assert_contains "$install_home/bin/llm-wiki" 'echo unrelated'

printf '%s\n' 'PASS: llm-wiki init, imports, status, install, and uninstall'
