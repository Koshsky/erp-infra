# Branch protection and verification stages (dev → staging → main)

All three repositories (`erp-infra`, `erp-backend`, `erp-frontend`) follow the
same branch flow:

```
feature/*, hotfix/*  ──PR──▶  dev  ──PR──▶  staging  ──PR──▶  main
   (development)         (integration)   (system testing,     (production)
                                          pre-production)
```

## How it works (and what GitHub cannot do out of the box)

Classic branch protection cannot restrict the **PR source branch** ("main
accepts PRs only from staging"). The rule is therefore implemented as a pair
of two parts:

1. **Direct pushes forbidden** to the branch + mandatory PR with review
   (protection settings in Settings → Branches).
2. **CI check of the PR source** — workflow `.github/workflows/ci.yml`,
   job `Branch policy` (check name **`CI / Branch policy`**): on the
   `pull_request` event it compares `github.head_ref` with `github.base_ref`:

   | base (PR target) | allowed source |
   |---|---|
   | `main` | `staging` |
   | `staging` | `dev` |
   | `dev` | `feature/*`, `hotfix/*` |
   | other | no restrictions |

   This check is then set as a **required status check** in the branch protection.

(New GitHub Rulesets also have no source-branch condition — the same CI
approach is needed. `branch policy` also catches PRs from forks: there
`head_ref` is the branch name of the fork.)

## CI checks besides the policy

- **erp-backend**: `Go tests` (build + `go test ./...`), `Golangci-lint`
  (golangci-lint v2.12.2, golden config from the repository).
- **erp-frontend**: `Typecheck & build` (`npm ci` → `vue-tsc` → `vite build`).
  Storybook/vitest checks can be added later: vitest in this repo runs through
  `@storybook/addon-vitest` and is not yet exposed as a separate `npm` script.
- **erp-infra**: only `Branch policy`. Checks like `docker compose config` /
  `nginx -t` need `.env` and secrets, which CI does not have — they are added
  separately once a staging environment with secrets exists.

## Enabling (one-time)

1. **Push the workflow** `.github/workflows/ci.yml` to each repository
   (in this session they live on `feature/ci-pipelines` branches — open PRs:
   `feature/ci-pipelines` → `dev` in each of the three repositories).
2. **Wait for the first run** of `CI / Branch policy` on any PR: the check
   appears in the list of available required checks (otherwise it cannot be
   selected).
3. **Enable protection** in one of two ways:

   **Script (fast, ×3 repositories):**
   ```bash
   gh auth login          # scope: repo
   ./scripts/branch-protection/apply-protection.sh
   ```

   **Or via the UI** (Settings → Branches → Add rule) — for each branch
   `main`, `staging`, `dev`:
   - ☑ Require a pull request before merging → 1 approval,
     ☑ Dismiss stale pull request approvals
   - ☑ Require status checks → ☑ Require branches to be up to date →
     select **`CI / Branch policy`**
   - ☑ Require conversation resolution
   - ☑ Restrict who can push → empty list (pushes only via PR)
   - Enforce all restrictions for administrators: `main`/`staging` ☑,
     `dev` ☐ (the owner pushes to dev directly)
   - ☑ Require linear history; force push and deletion — blocked

4. **Verify:**
   ```bash
   git push origin main                          # rejected
   # PR dev → main   -> CI / Branch policy red
   # PR staging → main -> CI / Branch policy green
   gh api repos/Koshsky/erp-backend/branches/main/protection
   ```

## Changing the policy

The PR-source rules are edited in the `policy` job of each
`.github/workflows/ci.yml`. The check name (`CI / Branch policy`) must not be
changed without updating `required_status_checks` in the protection — keep
them in sync.

## Limitations and next steps

- **Private submodules**: if `erp-backend`/`erp-frontend` are private, the
  root CI needs a PAT to verify gitlink pins — for now the root repository only
  checks the branch policy.
- **Forks**: a PR from a fork passes policy by the fork's branch name; if you
  need to restrict "from where" (own repository) too, add a check on
  `github.event.pull_request.head.repo.full_name`.
- **hotfix/**: `hotfix/*` branches are allowed into `dev` right away. Directly
  into `main` they **do not pass** — the policy only admits `staging` into
  `main`, so urgent production fixes go the usual way
  `hotfix/* → dev → staging → main`. If a `hotfix/* → main` bypass is needed,
  first add an exception in the `policy` job of each
  `.github/workflows/ci.yml` — there is none at the moment.