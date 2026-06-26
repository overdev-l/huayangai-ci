#!/usr/bin/env bash
set -euo pipefail

artifact="${1:-}"
if [[ -z "$artifact" || ! -f "$artifact" ]]; then
  echo "usage: deploy-systemd-binary /path/to/uploaded-binary" >&2
  exit 2
fi

: "${DEPLOY_SERVICE_NAME:?DEPLOY_SERVICE_NAME is required}"
: "${DEPLOY_ROOT:?DEPLOY_ROOT is required}"
: "${DEPLOY_BINARY_NAME:?DEPLOY_BINARY_NAME is required}"

deploy_user="${DEPLOY_USER:-app}"
deploy_group="${DEPLOY_GROUP:-app}"
retain_releases="${DEPLOY_RETAIN_RELEASES:-6}"

ts="$(date +%Y%m%d%H%M%S)"
release_dir="${DEPLOY_ROOT}/releases/${ts}"
bin_dir="${DEPLOY_ROOT}/bin"

install -d -o "$deploy_user" -g "$deploy_group" "$release_dir" "$bin_dir"
install -o "$deploy_user" -g "$deploy_group" -m 755 "$artifact" "${release_dir}/${DEPLOY_BINARY_NAME}"
ln -sfn "${release_dir}/${DEPLOY_BINARY_NAME}" "${bin_dir}/${DEPLOY_BINARY_NAME}"

systemctl daemon-reload
systemctl restart "${DEPLOY_SERVICE_NAME}.service"

for _ in {1..30}; do
  if systemctl is-active --quiet "${DEPLOY_SERVICE_NAME}.service"; then
    rm -f "$artifact"
    find "${DEPLOY_ROOT}/releases" -mindepth 1 -maxdepth 1 -type d |
      sort -r |
      tail -n +"$((retain_releases + 1))" |
      xargs -r rm -rf
    echo "deployed ${DEPLOY_SERVICE_NAME} release ${ts}"
    exit 0
  fi
  sleep 1
done

journalctl -u "${DEPLOY_SERVICE_NAME}.service" -n 160 --no-pager >&2 || true
exit 1
