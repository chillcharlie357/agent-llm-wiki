#!/bin/sh
set -eu

HARNESS=auto
BIN_DIR=${LLM_WIKI_BIN_DIR:-"$HOME/.local/bin"}

usage() {
  printf '%s\n' "Usage: ./uninstall.sh [--harness auto|all|codex|trae|claude|opencode|pi]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --harness) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; HARNESS=$2; shift 2 ;;
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

remove_for() {
  target="$(skill_root "$1")/llm-wiki"
  if [ -d "$target" ] && [ -f "$target/SKILL.md" ] && grep -q '^name: llm-wiki$' "$target/SKILL.md"; then
    rm -rf "$target"
    printf 'Removed: %s\n' "$target"
  fi
}

case "$HARNESS" in
  all) for name in codex trae claude opencode pi; do remove_for "$name"; done ;;
  auto)
    for name in codex trae claude opencode pi; do
      [ -d "$(skill_root "$name")/llm-wiki" ] && remove_for "$name" || true
    done
    ;;
  codex|trae|claude|opencode|pi) remove_for "$HARNESS" ;;
  *) printf 'Unsupported harness: %s\n' "$HARNESS" >&2; usage >&2; exit 2 ;;
esac

if [ -f "$BIN_DIR/llm-wiki" ] && grep -q '^# llm-wiki-cli$' "$BIN_DIR/llm-wiki"; then
  rm "$BIN_DIR/llm-wiki"
  printf 'Removed: %s\n' "$BIN_DIR/llm-wiki"
fi
if [ -f "$BIN_DIR/llm-wiki-hook" ] && grep -q '^# llm-wiki-hook$' "$BIN_DIR/llm-wiki-hook"; then
  rm "$BIN_DIR/llm-wiki-hook"
  printf 'Removed: %s\n' "$BIN_DIR/llm-wiki-hook"
fi
