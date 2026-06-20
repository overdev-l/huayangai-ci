# Huayang AI CI

This repository contains deployment automation for Huayang AI services.

Application source repository:

- `git@github.com:overdev-team/huayangai.git`

CI/deploy repository:

- `git@github.com:overdev-l/huayangai-ci.git`

## Tag-Based Deployments

Workflow: `.github/workflows/deploy-service.yml`

Because this workflow lives in the CI repository, GitHub only triggers it from tags pushed to `overdev-l/huayangai-ci`.

Use the same tag name in the application repository and the CI repository:

```bash
# Example: deploy API only.
TAG=api-v2026.06.20-1

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

Use the tag prefix to select services:

- `api-v2026.06.20-1`: deploy API only.
- `worker-v2026.06.20-1`: deploy worker only.
- `all-v2026.06.20-1`: deploy both API and worker.

Slash-style tags are also supported:

```bash
git tag api/2026.06.20-1
git tag worker/2026.06.20-1
git tag all/2026.06.20-1
```

The workflow can also be run manually from GitHub Actions by selecting:

- `service`: `api`, `worker`, or `all`
- `ref`: branch, tag, or commit SHA from `overdev-team/huayangai`

## What The Workflow Does

For each selected service, it performs:

1. Checkout `overdev-team/huayangai` at the tag/ref.
2. Optionally run `go -C apps/api test ./...`.
3. Build a Linux AMD64 binary:
   - API: `go -C apps/api build ... ./cmd/api`
   - Worker: `go -C apps/api build ... ./cmd/worker`
4. Upload the binary to the target server.
5. Run the server-side deploy script.

## Required Shared Secret

Set this secret in the CI repository:

- `CODE_REPO_SSH_KEY`: SSH private key with read access to `git@github.com:overdev-team/huayangai.git`.

## API Deployment Config

The API deployment is already prepared for the Aliyun ECS host.

Variables:

- `API_ECS_HOST`: API server host. Fallback: `ECS_HOST`.
- `API_ECS_USER`: API deploy user. Fallback: `ECS_USER`.
- `API_DEPLOY_SCRIPT`: optional, defaults to `/usr/local/bin/deploy-taro-miniapp-api`.

Secrets:

- `API_ECS_DEPLOY_SSH_KEY`: SSH private key for the API deploy user. Fallback: `ECS_DEPLOY_SSH_KEY`.

Current API server layout:

- API env file: `/etc/taro-miniapp-api/api.env`
- Blue instance: `127.0.0.1:8787`
- Green instance: `127.0.0.1:8788`
- Deploy script: `/usr/local/bin/deploy-taro-miniapp-api`
- Nginx reverse proxy: `/api/` -> active blue/green instance

## Worker Deployment Config

Set these before using `worker-*`, `worker/*`, `all-*`, or `all/*` tags.

Variables:

- `WORKER_ECS_HOST`: worker server host.
- `WORKER_ECS_USER`: worker deploy user.
- `WORKER_DEPLOY_SCRIPT`: optional, defaults to `/usr/local/bin/deploy-taro-miniapp-worker`.

Secrets:

- `WORKER_ECS_DEPLOY_SSH_KEY`: SSH private key for the worker deploy user.

The worker host should provide a compatible deploy script:

```bash
/usr/local/bin/deploy-taro-miniapp-worker /tmp/uploaded-worker-binary
```

That script should install the uploaded binary, restart or blue/green switch the worker service, and return non-zero on failure.

## Production Secrets

Production environment variables stay on the servers:

- API: `/etc/taro-miniapp-api/api.env`
- Worker: recommended `/etc/taro-miniapp-worker/worker.env`

Do not store production database URLs, provider API keys, storage keys, or payment secrets in GitHub Actions unless a future deployment design explicitly requires it.
