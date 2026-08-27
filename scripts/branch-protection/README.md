# Защита веток и этапы верификации (dev → staging → main)

Во всех трёх репозиториях (`erp-infra`, `erp-backend`, `erp-frontend`) действует
поток веток:

```
feature/*, hotfix/*  ──PR──▶  dev  ──PR──▶  staging  ──PR──▶  main
   (разработка)           (интеграция)   (системное тестирование,   (продакшен)
                                          пред-продакшен)
```

## Как это работает (и чего GitHub не умеет «из коробки»)

Kлассическая Branch protection не умеет ограничивать **ветку-источник PR**
(«main принимает PR только из staging»). Поэтому правило реализуется связкой
из двух частей:

1. **Запрет прямых пушей** в ветку + обязательный PR с ревью (настройка
   защиты в Settings → Branches).
2. **CI-проверка источника PR** — workflow `.github/workflows/ci.yml`,
   job `Branch policy` (check name **`CI / Branch policy`**): на событии
   `pull_request` сверяет `github.head_ref` с `github.base_ref`:

   | base (куда PR) | разрешённые source (откуда) |
   |---|---|
   | `main` | `staging` |
   | `staging` | `dev` |
   | `dev` | `feature/*`, `hotfix/*` |
   | прочее | без ограничений |

   Эта проверка и указывается как **required status check** в защите ветки.

(Новые GitHub Rulesets тоже не имеют условия по source-ветке — нужен тот же
CI-подход. `branch policy` ловит и PR из форков: `head_ref` там — имя ветки
форка.)

## Проверки в CI помимо политики

- **erp-backend**: `Go tests` (build + `go test ./...`), `Golangci-lint`
  (golangci-lint v2.12.2, golden config из репозитория).
- **erp-frontend**: `Typecheck & build` (`npm ci` → `vue-tsc` → `vite build`).
  Storybook/vitest-проверки можно добавить позже: vitest в этом репо идёт
  через `@storybook/addon-vitest` и пока не вынесен в отдельный `npm`-скрипт.
- **erp-infra**: только `Branch policy`. Проверки `docker compose config` /
  `nginx -t` требуют `.env` и секретов, которых нет в CI, — добавляются
  отдельно, когда появится staging-окружение с секретами.

## Порядок включения (однократно)

1. **Запушить workflow** `.github/workflows/ci.yml` в каждый репозиторий
   (в этой сессии они лежат на ветках `feature/ci-pipelines` — открыть PRы:
   `feature/ci-pipelines` → `dev` в каждом из трёх репозиториев).
2. **Дождаться первого прогона** `CI / Branch policy` на любом PR: проверка
   появится в списке доступных required checks (иначе её нельзя выбрать).
3. **Включить защиту** одним из способов:

   **Скрипт (быстро, ×3 репозитория):**
   ```bash
   gh auth login          # scope: repo
   ./scripts/branch-protection/apply-protection.sh
   ```

   **Или через UI** (Settings → Branches → Add rule) — на каждую ветку
   `main`, `staging`, `dev`:
   - ☑ Require a pull request before merging → 1 approval,
     ☑ Dismiss stale pull request approvals
   - ☑ Require status checks → ☑ Require branches to be up to date →
     отметить **`CI / Branch policy`**
   - ☑ Require conversation resolution
   - ☑ Restrict who can push → список пуст (пуши — только через PR)
   - Enforce all restrictions for administrators: `main`/`staging` ☑,
     `dev` ☐ (владелец пушит в dev напрямую)
   - ☑ Require linear history; force push и deletion — заблокированы

4. **Проверить:**
   ```bash
   git push origin main                          # rejected
   # PR dev → main   -> CI / Branch policy красный
   # PR staging → main -> CI / Branch policy зелёный
   gh api repos/Koshsky/erp-backend/branches/main/protection
   ```

## Смена политики

Правила источника PR правятся в job `policy` каждого
`.github/workflows/ci.yml`. Имя проверки (`CI / Branch policy`) менять нельзя
без обновления `required_status_checks` в защите — держите их синхронными.

## Ограничения и следующие шаги

- **Приватные подмодули**: если `erp-backend`/`erp-frontend` приватные,
  корневому CI для проверки gitlink-пинов понадобится PAT — пока корневой
  репозиторий проверяет только веточную политику.
- **Форки**: PR из форка проходит policy по имени ветки форка; если нужно
  ограничивать и «откуда» (свой репозиторий), добавьте проверку
  `github.event.pull_request.head.repo.full_name`.
- **hotfix/**: ветки `hotfix/*` разрешены в `dev` сразу; срочные фиксы в
  прод обычно идут `hotfix/* → main` — если хотите это запретить, добавьте
  в `policy` для `main` исключение.