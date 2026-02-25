#!/usr/bin/env bash
# eHive Console Installer for tunnel-manager (aarch64)
#
# Main functions:
# - require_root: ensure we run as root
# - ensure_cmd: fail fast if required commands are missing
# - download_and_verify_ttyd: fetch ttyd.aarch64 + SHA256SUMS and verify
# - install_systemd_unit: write /etc/systemd/system/ehive-console.service
# - enable_service: daemon-reload + enable + start
# - main: orchestrates installation

set -euo pipefail

TTYD_VER="${TTYD_VER:-1.7.7}"
PORT="${PORT:-3004}"
BIND_IP="${BIND_IP:-127.0.0.1}"
MAX_CLIENTS="${MAX_CLIENTS:-1}"
CMD="${CMD:-/bin/login}"

BIN="/usr/local/bin/ttyd"
UNIT="/etc/systemd/system/ehive-console.service"

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "ERROR: run as root" >&2; exit 1; }
}

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 1; }
}

download_and_verify_ttyd() {
  case "$(uname -m)" in
    aarch64|arm64) ;;
    *) echo "ERROR: only aarch64/arm64 supported (uname -m: $(uname -m))" >&2; exit 1 ;;
  esac

  ensure_cmd curl
  ensure_cmd sha256sum
  ensure_cmd install

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' RETURN

  curl -fsSL -o "${tmp}/ttyd.aarch64" \
    "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VER}/ttyd.aarch64"

  curl -fsSL -o "${tmp}/SHA256SUMS" \
    "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VER}/SHA256SUMS"

  ( cd "$tmp" && grep " ttyd.aarch64\$" SHA256SUMS | sha256sum -c - )

  install -m 0755 "${tmp}/ttyd.aarch64" "$BIN"
}

install_systemd_unit() {
  cat > "$UNIT" <<EOF
[Unit]
Description=eHive Browser Console (ttyd)
After=network.target

[Service]
Type=simple
User=root
ExecStart=${BIN} -p ${PORT} -i ${BIND_IP} -W -m ${MAX_CLIENTS} -O -t enableZmodem=true ${CMD}
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
}

enable_service() {
  ensure_cmd systemctl
  systemctl daemon-reload
  systemctl enable --now ehive-console.service
}

best_effort_lrzsz() {
  # optional: sz/rz für Filetransfer; darf failen (APT-Repo-Probleme)
  if command -v sz >/dev/null 2>&1; then
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y lrzsz >/dev/null 2>&1 || true
  fi
}

main() {
  require_root
  download_and_verify_ttyd
  best_effort_lrzsz
  install_systemd_unit
  enable_service
  echo "OK: eHive Console running at http://${BIND_IP}:${PORT}"
}

main "$@"
