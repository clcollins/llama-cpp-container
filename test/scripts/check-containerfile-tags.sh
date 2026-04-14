#!/usr/bin/env bash
# check-containerfile-tags.sh
#
# Validates that Containerfile FROM statements:
#   1. Do not use an implicit or explicit :latest tag.
#   2. Reference only trusted registries from the allowlist.
#
# Usage:
#   bash check-containerfile-tags.sh <Containerfile> [<Containerfile> ...]
#
# Environment:
#   ENFORCE=1  Exit non-zero on any violation. Default: warn only.

set -euo pipefail

ALLOWED_REGISTRIES=(
  "docker.io"
  "ghcr.io"
  "gcr.io"
  "quay.io"
  "registry.fedoraproject.org"
  "registry.access.redhat.com"
  "registry.redhat.io"
  "public.ecr.aws"
  "mcr.microsoft.com"
)

ENFORCE="${ENFORCE:-0}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <Containerfile> [<Containerfile> ...]" >&2
  exit 2
fi

violations=0

check_file() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "ERROR: ${file}: not found" >&2
    violations=$((violations + 1))
    return
  fi

  # First pass: collect all declared stage names from "FROM ... AS <stage>".
  local stages=()
  while IFS= read -r stage; do
    [ -z "$stage" ] && continue
    stages+=("$stage")
  done < <(grep -iE '^[[:space:]]*FROM[[:space:]]+.+[[:space:]]+AS[[:space:]]+[^[:space:]]+' "$file" \
             | awk '{print tolower($NF)}')

  is_local_stage() {
    local name="$1"
    local s
    for s in "${stages[@]}"; do
      if [ "$s" = "$name" ]; then
        return 0
      fi
    done
    return 1
  }

  # Second pass: validate each FROM <image> reference.
  while IFS= read -r image; do
    [ -z "$image" ] && continue

    # Skip references to locally declared multi-stage build stages.
    if is_local_stage "$(echo "$image" | tr '[:upper:]' '[:lower:]')"; then
      echo "OK: ${file}: FROM ${image} (local stage)"
      continue
    fi

    # Strip any @sha256:... digest for tag analysis.
    local ref="${image%@*}"

    # Disallow :latest (implicit or explicit).
    if [[ "$ref" == *":latest" ]]; then
      echo "ERROR: ${file}: explicit :latest tag in 'FROM ${image}'" >&2
      violations=$((violations + 1))
    elif [[ "$ref" != *":"* ]]; then
      echo "ERROR: ${file}: missing tag (implicit :latest) in 'FROM ${image}'" >&2
      violations=$((violations + 1))
    fi

    # Registry check: must start with one of the allowlist entries.
    local registry="${ref%%/*}"
    if [[ "$registry" != *"."* ]] && [[ "$registry" != *":"* ]]; then
      # No dot/colon in first segment means no registry specified; defaults to docker.io.
      registry="docker.io"
    fi

    local allowed=0
    for allowed_reg in "${ALLOWED_REGISTRIES[@]}"; do
      if [ "$registry" = "$allowed_reg" ]; then
        allowed=1
        break
      fi
    done

    if [ "$allowed" -eq 0 ]; then
      echo "ERROR: ${file}: registry '${registry}' not in allowlist (FROM ${image})" >&2
      violations=$((violations + 1))
    else
      echo "OK: ${file}: FROM ${image}"
    fi
  done < <(grep -iE '^[[:space:]]*FROM[[:space:]]+' "$file" | awk '{print $2}')
}

for f in "$@"; do
  check_file "$f"
done

if [ "$violations" -gt 0 ]; then
  echo "" >&2
  echo "Found ${violations} violation(s)." >&2
  if [ "$ENFORCE" = "1" ]; then
    exit 1
  fi
fi

exit 0
