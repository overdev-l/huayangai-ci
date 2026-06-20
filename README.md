# Huayang AI CI

This repository contains deployment automation for the Huayang AI services.

## API Deployment

Workflow: `.github/workflows/deploy-api.yml`

It performs:

1. Checkout `overdev-team/huayangai`.
2. Run Go API tests.
3. Build a Linux AMD64 API binary.
4. Upload the binary to the Aliyun ECS host.
5. Run the server-side blue/green deployment script.

## Required GitHub Secrets

Set these secrets in this CI repository:

- `CODE_REPO_SSH_KEY`: SSH private key with read access to `git@github.com:overdev-team/huayangai.git`.
- `ECS_DEPLOY_SSH_KEY`: SSH private key for the `deploy` user on the ECS host.

## Required GitHub Variables

Set these repository variables:

- `ECS_HOST`: `47.116.171.200`
- `ECS_USER`: `deploy`

## Server Layout

The ECS host is prepared with:

- API env file: `/etc/taro-miniapp-api/api.env`
- Blue instance: `127.0.0.1:8787`
- Green instance: `127.0.0.1:8788`
- Deploy script: `/usr/local/bin/deploy-taro-miniapp-api`
- Nginx reverse proxy: `/api/` -> active blue/green instance

Production secrets stay on the server in `/etc/taro-miniapp-api/api.env`; they are not stored in GitHub Actions.
