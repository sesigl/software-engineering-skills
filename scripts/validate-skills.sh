#!/usr/bin/env bash
# Validate every skill in skills/ against the Agent Skills specification,
# Claude 5 generation skill rules, and plugin marketplace manifests.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${ROOT_DIR}/skills"
PASS=0
WARN=0
FAIL=0
SKILL_COUNT=0

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

err()  { printf "  ${RED}x${NC} %s\n" "$1"; FAIL=$((FAIL + 1)); }
warn() { printf "  ${YELLOW}!${NC} %s\n" "$1"; WARN=$((WARN + 1)); }
ok()   { printf "  ${GREEN}v${NC} %s\n" "$1"; PASS=$((PASS + 1)); }

printf "${CYAN}Validating marketplace manifests${NC}\n"

for manifest in ".claude-plugin/marketplace.json" ".claude-plugin/plugin.json" ".cursor-plugin/plugin.json"; do
  if [[ ! -f "${ROOT_DIR}/${manifest}" ]]; then
    err "Missing manifest: ${manifest}"
  elif python3 -m json.tool "${ROOT_DIR}/${manifest}" >/dev/null 2>&1; then
    ok "${manifest} is valid JSON"
  else
    err "${manifest} contains invalid JSON"
  fi
done

printf "\n${CYAN}Validating skills in %s${NC}\n\n" "$SKILLS_DIR"

if [[ ! -d "$SKILLS_DIR" ]]; then
  err "skills/ directory not found"
  exit 1
fi

for skill_dir in "$SKILLS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  SKILL_COUNT=$((SKILL_COUNT + 1))
  skill_name="$(basename "$skill_dir")"
  skill_md="${skill_dir}SKILL.md"

  printf "${CYAN}%s${NC}\n" "$skill_name"

  if [[ ! -f "$skill_md" ]]; then
    err "SKILL.md missing"
    continue
  fi

  if [[ ! "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    err "Folder name must use lowercase letters, numbers, and hyphens only"
  else
    ok "Folder name format valid"
  fi

  first_line="$(head -n1 "$skill_md")"
  if [[ "$first_line" != "---" ]]; then
    err "SKILL.md must start with YAML frontmatter (---)"
    continue
  fi

  frontmatter="$(awk '/^---[[:space:]]*$/{n++; next} n==1{print} n==2{exit}' "$skill_md")"

  yaml_name="$(printf "%s\n" "$frontmatter" | awk -F': ' '/^name:/{print $2; exit}' | tr -d '"' | tr -d "'" | tr -d '[:space:]')"
  if [[ -z "$yaml_name" ]]; then
    err "name field missing from frontmatter"
  elif [[ "$yaml_name" != "$skill_name" ]]; then
    err "Frontmatter name '$yaml_name' does not match directory '$skill_name'"
  elif [[ ${#yaml_name} -gt 64 ]]; then
    err "Frontmatter name exceeds 64 characters (${#yaml_name})"
  elif [[ "$yaml_name" == *"anthropic"* || "$yaml_name" == *"claude"* ]]; then
    err "Frontmatter name must not contain 'anthropic' or 'claude'"
  else
    ok "name matches folder and obeys platform constraints"
  fi

  desc_block="$(printf "%s\n" "$frontmatter" | awk '
    BEGIN{in_desc=0}
    /^description:/{
      sub(/^description:[ \t]*/, "")
      if ($0 ~ /^>/ || $0 ~ /^\|/) { in_desc=1; next }
      print; exit
    }
    in_desc==1 {
      if ($0 ~ /^[a-zA-Z_-]+:/) exit
      sub(/^[ \t]+/, "")
      printf "%s ", $0
    }
  ')"

  desc_len=${#desc_block}
  if [[ $desc_len -eq 0 ]]; then
    err "description field missing or empty"
  elif [[ $desc_len -gt 1024 ]]; then
    err "description is $desc_len chars (max 1024)"
  elif [[ "$desc_block" =~ \<[a-zA-Z/][^›]*\> ]]; then
    err "description must not contain XML tags"
  else
    ok "description present and within 1024-char limit ($desc_len chars)"
  fi

  if [[ "$desc_block" == *"Use when"* || "$desc_block" == *"use when"* ]]; then
    ok "description includes trigger phrasing"
  else
    warn "description should include 'Use when' trigger phrasing"
  fi

  line_count="$(wc -l < "$skill_md" | tr -d '[:space:]')"
  if [[ $line_count -ge 500 ]]; then
    err "SKILL.md is $line_count lines (must be < 500 lines)"
  else
    ok "SKILL.md line count under 500 ($line_count lines)"
  fi

  if [[ -f "${skill_dir}evals/evals.json" ]]; then
    if python3 -m json.tool "${skill_dir}evals/evals.json" >/dev/null 2>&1; then
      ok "evals/evals.json is valid JSON"
    else
      err "evals/evals.json contains invalid JSON"
    fi
  else
    warn "evals/evals.json not found"
  fi

  printf "\n"
done

printf "${CYAN}Summary${NC}\n"
printf "  Skills checked: %d\n" "$SKILL_COUNT"
printf "  ${GREEN}Passed:${NC}         %d\n" "$PASS"
printf "  ${YELLOW}Warnings:${NC}       %d\n" "$WARN"
printf "  ${RED}Failed:${NC}         %d\n" "$FAIL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
