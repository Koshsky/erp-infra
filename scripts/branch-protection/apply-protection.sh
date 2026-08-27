#!/usr/bin/env bash
# Применяет защиту веток main/staging/dev в трёх репозиториях через gh CLI.
#
# Требования:
#   - gh установлен и авторизован:  gh auth login  (scope: repo)
#   - у вашего аккаунта есть права администратора в Koshsky/erp-infra,
#     Koshsky/erp-backend, Koshsky/erp-frontend
#
# Что настраивается на каждой ветке:
#   - PR обязателен, 1 approval, stale-approvals отклоняются
#   - required status check: "CI / Branch policy" (gitlink workflow из
#     .github/workflows/ci.yml) + strict (ветка должна быть актуальной)
#   - прямые пуши запрещены (restrictions пустые) — только через PR;
#     для dev enforce_admins=false, чтобы владелец мог пушить напрямую
#   - linear history, force push и удаление ветки запрещены
#
# GitHub не умеет ограничивать ветку-источник PR «из коробки» — само правило
# «main ← только staging» выполняет CI-проверка "CI / Branch policy".
set -euo pipefail

REPOS=(Koshsky/erp-infra Koshsky/erp-backend Koshsky/erp-frontend)
CHECK_CONTEXT="CI / Branch policy"
REQUIRED_REVIEWS=1

if ! gh auth status >/dev/null 2>&1; then
  echo "Ошибка: gh не авторизован. Выполните: gh auth login" >&2
  exit 1
fi

payload="$(mktemp)"
trap 'rm -f "$payload"' EXIT

for repo in "${REPOS[@]}"; do
  for branch in main staging dev; do
    if [ "$branch" = "dev" ]; then
      enforce="false"   # владелец может пушить в dev напрямую
    else
      enforce="true"    # main/staging: защита действует и на админов
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
  "restrictions": { "users": [], "teams": [], "apps": [] },
  "required_linear_history": true,
  "allow_force_pushes": { "enabled": false },
  "allow_deletions": { "enabled": false }
}
EOF

    echo "==> $repo / $branch"
    gh api -X PUT "repos/$repo/branches/$branch/protection" --input "$payload" >/dev/null
    echo "    ok: PR обязателен, required context '$CHECK_CONTEXT', direct push запрещён"
  done
done

echo
echo "Готово. Проверка: gh api repos/Koshsky/erp-backend/branches/main/protection"