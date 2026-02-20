#!/usr/bin/env bash
set -euo pipefail

RUN_ID="${1:-}"
JUMP_GROUP="${2:-}"

if [[ -z "$RUN_ID" || -z "$JUMP_GROUP" ]]; then
  echo "Usage: $0 <runId> <jumpGroup>"
  exit 1
fi

check_connectivity() {
  local url="https://pa-test.trivadis.com"
  local max_attempts=12
  local delay_seconds=10

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    echo "[Connectivity] Attempt ${attempt}/${max_attempts} -> ${url}"
    if curl -kfsS --max-time 15 "$url" >/dev/null; then
      echo "[Connectivity] Endpoint reachable."
      return 0
    fi
    sleep "$delay_seconds"
  done

  echo "[Connectivity] Unable to reach ${url} after ${max_attempts} attempts." >&2
  return 1
}

echo "Preparing BeyondTrust Jump Client setup for RunId=${RUN_ID}, JumpGroup=${JUMP_GROUP}"
check_connectivity

install_root="/opt/beyondtrust/lab-bootstrap"
log_file="${install_root}/jump-client-install.log"
cmd_file="${install_root}/install_jump_client.sh"

sudo mkdir -p "$install_root"

cat <<EOF | sudo tee "$cmd_file" >/dev/null
#!/usr/bin/env bash
set -euo pipefail
./BeyondTrustJumpClient.run --quiet --nox11 --accept-eula \\
  --run-id "${RUN_ID}" \\
  --jump-group "${JUMP_GROUP}" \\
  --install-scope machine
EOF

sudo chmod 750 "$cmd_file"
echo "$(date -Iseconds) Prepared Jump Client silent installation command in ${cmd_file}" | sudo tee -a "$log_file" >/dev/null

echo "Jump Client preparation completed. Command script: ${cmd_file}"
