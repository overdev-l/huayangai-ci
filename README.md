# Huayang AI CI

This repository contains deployment automation for Huayang AI services.

Application source repository:

- `git@github.com:overdev-team/huayangai.git`

CI/deploy repository:

- `git@github.com:overdev-l/huayangai-ci.git`

## Environments

| Environment | API | Worker |
| --- | --- | --- |
| `pre` | Singapore ECS, `https://pre-huyangai-api.overdev.cn` | Singapore ECS |
| `prod` | Aliyun ECS, `https://huayangai-api.overdev.cn` | Singapore ECS |

The production worker still runs on the Singapore machine, but it should be a separate systemd service and env file from the pre worker.

## Tag-Based Deployments

Workflow: `.github/workflows/deploy-service.yml`

Because this workflow lives in the CI repository, GitHub only triggers it from tags pushed to `overdev-l/huayangai-ci`.

Use the same tag name in the application repository and the CI repository:

```bash
# Example: deploy pre API only.
TAG=pre-api-v2026.06.20-1

# 1. Tag and push the application release.
cd /path/to/huayangai
git tag "$TAG"
git push origin "$TAG"

# 2. Trigger CI with a same-named tag in the CI repository.
# Do not push the application tag object directly to the CI repository.
cd /path/to/huayangai-ci
git fetch origin main
git tag "$TAG" origin/main
git push origin "$TAG"
```

The CI workflow checks out `overdev-team/huayangai` at the triggering tag name. If the tag exists only in the CI repository and not in the application repository, checkout will fail.

Use the tag prefix to select environment and service:

- `pre-api-v2026.06.20-1`: deploy pre API only.
- `pre-worker-v2026.06.20-1`: deploy pre worker only.
- `pre-all-v2026.06.20-1`: deploy pre API and pre worker.
- `prod-api-v2026.06.20-1`: deploy production API only.
- `prod-worker-v2026.06.20-1`: deploy production worker only.
- `prod-all-v2026.06.20-1`: deploy production API and production worker.

Slash-style tags are also supported:

```bash
git tag pre/api/2026.06.20-1
git tag pre/worker/2026.06.20-1
git tag pre/all/2026.06.20-1
git tag prod/api/2026.06.20-1
git tag prod/worker/2026.06.20-1
git tag prod/all/2026.06.20-1
```

Legacy tags `api-v*`, `worker-v*`, `all-v*`, `api/*`, `worker/*`, and `all/*` still work, and are treated as production deploys.

The workflow can also be run manually from GitHub Actions by selecting:

- `environment`: `pre` or `prod`
- `service`: `api`, `worker`, or `all`
- `ref`: branch, tag, or commit SHA from `overdev-team/huayangai`

## What The Workflow Does

For each selected target, it performs:

1. Checkout `overdev-team/huayangai` at the tag/ref.
2. Optionally run `go -C apps/api test ./...`.
3. Build a Linux AMD64 binary:
   - API: `go -C apps/api build ... ./cmd/api`
   - Worker: `go -C apps/api build ... ./cmd/worker`
4. Upload the binary to the target server.
5. Run the server-side deploy script.
6. For API deploys, verify the public `/health` endpoint.

## Required GitHub Secret

Set this secret in the CI repository:

- `CODE_REPO_SSH_KEY`: SSH private key with read access to `git@github.com:overdev-team/huayangai.git`.

## Required GitHub Variables And Secrets

You can set shared Singapore credentials once, then override individual targets only when needed.

Shared Singapore server:

- Variable `SINGAPORE_ECS_HOST`: Singapore ECS host, for example `161.118.250.139`.
- Variable `SINGAPORE_ECS_USER`: SSH user, for example `ubuntu`.
- Secret `SINGAPORE_ECS_DEPLOY_SSH_KEY`: private key for that user.

Production Aliyun API server:

- Variable `PROD_API_ECS_HOST`: Aliyun ECS host, for example `47.116.171.200`.
- Variable `PROD_API_ECS_USER`: SSH user, for example `ubuntu`.
- Secret `PROD_API_ECS_DEPLOY_SSH_KEY`: private key for that user.

Optional deploy script overrides:

- `PRE_API_DEPLOY_SCRIPT`, default `/usr/local/bin/deploy-huayangai-pre-api`
- `PRE_WORKER_DEPLOY_SCRIPT`, default `/usr/local/bin/deploy-huayangai-pre-worker`
- `PROD_API_DEPLOY_SCRIPT`, default `/usr/local/bin/deploy-huayangai-prod-api`
- `PROD_WORKER_DEPLOY_SCRIPT`, default `/usr/local/bin/deploy-huayangai-prod-worker`

Optional health URL overrides:

- `PRE_API_HEALTH_URL`, default `https://pre-huyangai-api.overdev.cn/health`
- `PROD_API_HEALTH_URL`, default `https://huayangai-api.overdev.cn/health`

Optional build architecture overrides:

- `SINGAPORE_GOARCH`, default `arm64`
- `ALIYUN_GOARCH`, default `amd64`
- `PRE_API_GOARCH`, `PRE_WORKER_GOARCH`, `PROD_API_GOARCH`, `PROD_WORKER_GOARCH` for per-target overrides

## Recommended Server Layout

Keep each environment/service isolated:

| Target | systemd service | YAML config | Install root |
| --- | --- | --- | --- |
| pre API | `huayangai-pre-api.service` | `/etc/huayangai/pre.yaml` | `/opt/huayangai/pre/api` |
| pre worker | `huayangai-pre-worker.service` | `/etc/huayangai/pre.yaml` | `/opt/huayangai/pre/worker` |
| prod API | `huayangai-prod-api.service` | `/etc/huayangai/prod.yaml` | `/opt/huayangai/prod/api` |
| prod worker | `huayangai-prod-worker.service` | `/etc/huayangai/prod.yaml` | `/opt/huayangai/prod/worker` |

The deploy workflow also copies the selected YAML to `config.yaml` under the target service working directory, so the binary can start even when the systemd unit does not export an environment selector.

The generic helper script is in `scripts/deploy-systemd-binary.sh`. Install it on each server as:

```bash
sudo install -m 755 scripts/deploy-systemd-binary.sh /usr/local/lib/huayangai/deploy-systemd-binary
```

Then create small wrapper scripts per target. Example for pre API:

```bash
sudo tee /usr/local/bin/deploy-huayangai-pre-api >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export DEPLOY_SERVICE_NAME=huayangai-pre-api
export DEPLOY_ROOT=/opt/huayangai/pre/api
export DEPLOY_BINARY_NAME=api
exec /usr/local/lib/huayangai/deploy-systemd-binary "$@"
EOF
sudo chmod +x /usr/local/bin/deploy-huayangai-pre-api
```

Example systemd unit for pre API:

```ini
[Unit]
Description=Huayang AI Pre API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=app
Group=app
WorkingDirectory=/opt/huayangai/pre/api
Environment=HUAYANG_ENV=pre
ExecStart=/opt/huayangai/pre/api/bin/api
Restart=always
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

The worker unit is the same pattern, with `ExecStart=/opt/huayangai/<env>/worker/bin/worker`.

## Secrets Stay On Servers

Runtime environment variables stay on the servers. Do not store production database URLs, provider API keys, storage keys, or payment secrets in GitHub Actions unless a future deployment design explicitly requires it.
