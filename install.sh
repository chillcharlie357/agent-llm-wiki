#!/bin/sh
set -eu

# Install the llm-wiki skill and hook adapter for Agent Skills compatible harnesses.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_SOURCE="$ROOT_DIR/skills/llm-wiki"
HARNESS=auto
FORCE=0
BIN_DIR=${LLM_WIKI_BIN_DIR:-"$HOME/.local/bin"}

usage() {
  printf '%s\n' \
    "Usage: ./install.sh [--harness auto|all|codex|trae|claude|opencode|pi] [--force]" \
    "" \
    "Installs the llm-wiki Agent Skill and the llm-wiki command."
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --harness)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      HARNESS=$2
      shift 2
      ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

skill_root() {
  case "$1" in
    codex) printf '%s\n' "${LLM_WIKI_CODEX_SKILLS_DIR:-$HOME/.agents/skills}" ;;
    trae) printf '%s\n' "${LLM_WIKI_TRAE_SKILLS_DIR:-$HOME/.trae/skills}" ;;
    claude) printf '%s\n' "${LLM_WIKI_CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}" ;;
    opencode) printf '%s\n' "${LLM_WIKI_OPENCODE_SKILLS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills}" ;;
    pi) printf '%s\n' "${LLM_WIKI_PI_SKILLS_DIR:-$HOME/.pi/agent/skills}" ;;
    *) return 1 ;;
  esac
}

is_detected() {
  case "$1" in
    codex) [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1 ;;
    trae) [ -d "$HOME/.trae" ] || command -v trae >/dev/null 2>&1 ;;
    claude) [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1 ;;
    opencode) [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/opencode" ] || command -v opencode >/dev/null 2>&1 ;;
    pi) [ -d "$HOME/.pi" ] || command -v pi >/dev/null 2>&1 ;;
  esac
}

install_for() {
  name=$1
  root=$(skill_root "$name")
  target="$root/llm-wiki"
  mkdir -p "$root"
  if [ -e "$target" ] && [ "$FORCE" -ne 1 ]; then
    printf 'Already exists: %s (use --force to replace)\n' "$target" >&2
    return 1
  fi
  if [ -e "$target" ]; then
    if [ ! -f "$target/SKILL.md" ] || ! grep -q '^name: llm-wiki$' "$target/SKILL.md"; then
      printf 'Refusing to replace an unrecognized directory: %s\n' "$target" >&2
      return 1
    fi
    rm -rf "$target"
  fi
  cp -R "$SKILL_SOURCE" "$target"
  printf 'Installed llm-wiki skill for %s: %s\n' "$name" "$target"
}

[ -d "$SKILL_SOURCE" ] || { printf 'Missing skill source: %s\n' "$SKILL_SOURCE" >&2; exit 1; }
if [ -e "$BIN_DIR/llm-wiki" ] && ! grep -q '^# llm-wiki-cli$' "$BIN_DIR/llm-wiki"; then
  printf 'Refusing to replace an unrecognized command: %s\n' "$BIN_DIR/llm-wiki" >&2
  exit 1
fi
if [ -e "$BIN_DIR/llm-wiki-hook" ] && ! grep -q '^# llm-wiki-hook$' "$BIN_DIR/llm-wiki-hook"; then
  printf 'Refusing to replace an unrecognized command: %s\n' "$BIN_DIR/llm-wiki-hook" >&2
  exit 1
fi

installed=0
case "$HARNESS" in
  all)
    for name in codex trae claude opencode pi; do install_for "$name"; installed=$((installed + 1)); done
    ;;
  auto)
    for name in codex trae claude opencode pi; do
      if is_detected "$name"; then install_for "$name"; installed=$((installed + 1)); fi
    done
    if [ "$installed" -eq 0 ]; then
      printf '%s\n' "No supported harness was detected. Re-run with --harness <name>." >&2
      exit 1
    fi
    ;;
  codex|trae|claude|opencode|pi) install_for "$HARNESS"; installed=1 ;;
  *) printf 'Unsupported harness: %s\n' "$HARNESS" >&2; usage >&2; exit 2 ;;
esac

mkdir -p "$BIN_DIR"
cp "$SKILL_SOURCE/scripts/llm-wiki" "$BIN_DIR/llm-wiki"
cp "$SKILL_SOURCE/scripts/llm-wiki-hook" "$BIN_DIR/llm-wiki-hook"
chmod +x "$BIN_DIR/llm-wiki" "$BIN_DIR/llm-wiki-hook"
printf 'Installed commands: %s, %s\n' "$BIN_DIR/llm-wiki" "$BIN_DIR/llm-wiki-hook"
case :"$PATH": in
  *:"$BIN_DIR":*) ;;
  *) printf 'Add %s to PATH to call llm-wiki directly.\n' "$BIN_DIR" ;;
esac
