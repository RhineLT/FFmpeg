#!/usr/bin/env bash
set -euo pipefail

# Watch workflow run associated with current HEAD using GitHub CLI
# Requirements: gh auth login

WF_FILE=${1:-build-ios.yml}
BRANCH=${2:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}

echo "[gh] Seeking run for workflow=$WF_FILE branch=$BRANCH ..."

SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
RUN_ID=""

if [ -n "$SHA" ]; then
  # Try to find a run triggered by the current commit
  RUN_ID=$(gh run list --workflow "$WF_FILE" --branch "$BRANCH" --json databaseId,headSha,status,createdAt \
    -q "map(select(.headSha == '$SHA')) | .[0].databaseId" || true)
fi

if [ -z "$RUN_ID" ]; then
  # Fallback: latest run of this workflow on the branch
  RUN_ID=$(gh run list --workflow "$WF_FILE" --branch "$BRANCH" --json databaseId,status,createdAt -q '.[0].databaseId' || true)
fi

if [ -z "$RUN_ID" ]; then
  echo "[gh] No runs found for $WF_FILE on $BRANCH" >&2
  exit 1
fi

echo "[gh] Streaming logs for run $RUN_ID"
gh run watch "$RUN_ID" --exit-status --interval 10
