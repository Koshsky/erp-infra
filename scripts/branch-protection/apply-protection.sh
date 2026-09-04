#!/usr/bin/env bash
# Applies main/staging/dev branch protection in the three repositories via the gh CLI.
#
# Requirements:
#   - gh installed and authenticated:  gh auth login  (scope: repo)
#   - your account has admin rights in Koshsky/erp-infra,
#     Koshsky/erp-backend, Koshsky/erp-frontend
#
# What is configured on each branch:
#   - PR required, 1 approval, stale approvals rejected
#   - required status check: "CI / Branch policy" (gitlink workflow from
#     .github/workflows/ci.yml) + strict (branch must be up to date)
#   - unresolved threads block merge (required_conversation_resolution)
#   - direct pushes forbidden (empty restrictions) — only via PR;
#     for dev enforce_admins=false so the owner can push directly
#   - linear history, force push and branch deletion forbidden
#
# GitHub cannot restrict the PR source branch out of the box — the rule
# "main ← staging only" is enforced by the CI check "CI / Branch policy".
set -euo pipefail

REPOS=(Koshsky/erp-infra Koshsky/erp-backend Koshsky/erp-frontend)
CHECK_CONTEXT="CI / Branch policy"
REQUIRED_REVIEWS=1

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh is not authenticated. Run 'gh auth login'." >&2
  exit 1
fi

payload="$(mktemp)"
trap 'rm -f "$payload"' EXIT

for repo in "${REPOS[@]}"; do
  for branch in main staging dev; do
    if [ "$branch" = "dev" ]; then
      enforce="false"   # the owner can push to dev directly
    else
      enforce="true"    # main/staging: protection applies to admins too
    fi

    cat >"$payload" <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["$CHECK_CONTEXT"]
  },
  "enforce_admins": $enforce,
  "required_pull_request_reviews": {
    "required_approving_review_count": $REQUIRED_REVIEWS,
    "dismiss_stale_reviews": true
  },
  "required_conversation_resolution": true,
  "restrictions": { "users": [], "teams": [], "apps": [] },
  "required_linear_history": true,
  "allow_force_pushes": { "enabled": false },
  "allow_deletions": { "enabled": false }
}
EOF

    echo "==> $repo / $branch"
    gh api -X PUT "repos/$repo/branches/$branch/protection" --input "$payload" >/dev/null
    echo "    ok: pull requests required, required check '$CHECK_CONTEXT', direct push restricted"
  done
done

echo
echo "Done. Verify with: gh api repos/Koshsky/erp-backend/branches/main/protection"