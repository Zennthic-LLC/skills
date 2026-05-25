#!/usr/bin/env bash
# Link each packaged skill into ~/.claude/skills/<name> so Claude Code
# (CLI and cloud/web sessions) discovers them.
#
# The repo is laid out as a plugin marketplace (<tool>/skills/<name>/SKILL.md),
# which Claude Code's interactive /plugin install understands. But filesystem
# skill discovery scans ~/.claude/skills/<name>/SKILL.md (one level deep), so a
# plain clone of the repo root is NOT discovered. This script bridges that gap.
#
# Usage:
#   git clone --depth 1 https://github.com/Zennthic-LLC/skills.git
#   bash skills/scripts/install-skills.sh
#
# Override the destination with CLAUDE_SKILLS_DIR (defaults to ~/.claude/skills).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$dest"

shopt -s nullglob
linked=0
for skill_md in "$repo_root"/*/skills/*/SKILL.md; do
  skill_dir="$(dirname "$skill_md")"
  name="$(basename "$skill_dir")"
  target="$dest/$name"
  rm -rf "$target"
  ln -s "$skill_dir" "$target"
  echo "linked $name -> $skill_dir"
  linked=$((linked + 1))
done

if [ "$linked" -eq 0 ]; then
  echo "No skills found under $repo_root/*/skills/*/SKILL.md" >&2
  exit 1
fi
echo "Linked $linked skill(s) into $dest"
