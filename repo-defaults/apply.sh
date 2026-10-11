#!/usr/bin/env bash
# Brings a repo in line with the defaults in this folder. With --check, only reports what differs
# and exits 1 if anything does. Needs gh (logged in as a repo admin) and jq.
# Usage: repo-defaults/apply.sh [--check] OWNER/REPO
set -euo pipefail

check=false
if [ "${1:-}" = "--check" ]; then
  check=true
  shift
fi
repo="${1:?usage: apply.sh [--check] OWNER/REPO}"
dir="$(cd "$(dirname "$0")" && pwd)"
drift=0

# Keeps only the keys the default sets, so settings it doesn't manage never count as drift.
# shellcheck disable=SC2016 # jq's variables, not the shell's.
shape='def shape($w): if ($w | type) == "object" then . as $v | reduce ($w | keys[]) as $k ({}; .[$k] = ($v[$k] | shape($w[$k]))) else . end;'

# Rules and bypass actors come back in any order.
normalize='if type == "object" and has("rules") then .rules |= sort_by(.type) | .bypass_actors |= sort_by(.actor_type, .actor_id) else . end'

# Prints a diff and returns 1 when the current value isn't the default.
differs() {
  local name="$1" have="$2" want="$3"
  if diff -u --label "$name (current)" --label "$name (default)" \
    <(jq -S "$normalize" <<< "$have") <(jq -S "$normalize" <<< "$want"); then
    echo "✓ $name"
    return 1
  fi
  drift=1
  return 0
}

fix() {
  if [ "$check" = false ]; then
    "$@" > /dev/null
    echo "  → updated"
  fi
}

want="$(cat "$dir/settings.json")"
have="$(gh api "repos/$repo" | jq --argjson want "$want" "$shape shape(\$want)")"
if differs "settings" "$have" "$want"; then
  fix gh api -X PATCH "repos/$repo" --input "$dir/settings.json"
fi

# 204 when on, 404 when off.
if gh api "repos/$repo/vulnerability-alerts" --silent 2> /dev/null; then
  echo "✓ dependabot alerts"
else
  echo "✗ dependabot alerts are off"
  drift=1
  fix gh api -X PUT "repos/$repo/vulnerability-alerts"
fi

want="$(cat "$dir/workflow-permissions.json")"
have="$(gh api "repos/$repo/actions/permissions/workflow")"
if differs "workflow permissions" "$have" "$want"; then
  fix gh api -X PUT "repos/$repo/actions/permissions/workflow" --input "$dir/workflow-permissions.json"
fi

want="$(cat "$dir/ruleset-main.json")"
name="$(jq -r .name <<< "$want")"
id="$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\" and .source_type == \"Repository\") | .id")"
if [ -z "$id" ]; then
  echo "✗ no \"$name\" ruleset"
  drift=1
  fix gh api -X POST "repos/$repo/rulesets" --input "$dir/ruleset-main.json"
else
  have="$(gh api "repos/$repo/rulesets/$id" | jq '{name, target, enforcement, conditions, rules, bypass_actors}')"
  if differs "\"$name\" ruleset" "$have" "$want"; then
    fix gh api -X PUT "repos/$repo/rulesets/$id" --input "$dir/ruleset-main.json"
  fi
fi

# Files are only reported: they belong in a PR to the repo.
for file in .github/CODEOWNERS .github/pull_request_template.md .github/renovate.json .github/workflows/check.yml; do
  if gh api "repos/$repo/contents/$file" --silent 2> /dev/null; then
    echo "✓ $file"
  else
    echo "✗ missing $file (add it in a PR)"
    drift=1
  fi
done

# The release workflow can't run without the App's Client ID and key, and neither can be set from here.
if gh api "repos/$repo/contents/.github/workflows/release.yml" --silent 2> /dev/null; then
  if gh variable list -R "$repo" --json name --jq '.[].name' | grep -qx RELEASE_APP_CLIENT_ID; then
    echo "✓ RELEASE_APP_CLIENT_ID variable"
  else
    echo "✗ missing the RELEASE_APP_CLIENT_ID variable (BriansBot's Client ID)"
    drift=1
  fi
  if gh secret list -R "$repo" --json name --jq '.[].name' | grep -qx RELEASE_APP_PRIVATE_KEY; then
    echo "✓ RELEASE_APP_PRIVATE_KEY secret"
  else
    echo "✗ missing the RELEASE_APP_PRIVATE_KEY secret (BriansBot's private key)"
    drift=1
  fi
fi

if [ "$check" = true ]; then
  exit "$drift"
fi
