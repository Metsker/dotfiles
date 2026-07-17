#!/usr/bin/env bash

input=$(cat)

main=$(printf '%s' "$input" | jq -r '
  [ .model.display_name,
    (.effort.level // empty),
    "\(.context_window.used_percentage // 0 | round)%"
  ] | join(" · ")')

dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "."')
branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null) \
  || branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)

if [ -n "$branch" ]; then
  printf '%s · %s\n' "$main" "$branch"
else
  printf '%s\n' "$main"
fi
