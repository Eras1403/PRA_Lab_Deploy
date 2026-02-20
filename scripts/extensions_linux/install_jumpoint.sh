#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Dieses Skript bereitet eine unbeaufsichtigte ("silent") Installation eines
# BeyondTrust Jumpoint auf Linux vor.
#
# Wichtige Designentscheidung:
# - Das Skript installiert Jumpoint NICHT direkt.
# - Stattdessen erzeugt es unter /opt/beyondtrust/lab-bootstrap ein ausführbares
#   Kommando-Skript (install_jumpoint.sh), das den eigentlichen Installer mit den
#   korrekten Parametern ausführt.
#
# Warum dieser Ansatz?
# - Die Bereitstellung kann in mehreren Schritten erfolgen (z. B. Download,
#   Vorbereitung, späteres Ausführen durch einen separaten Provisioning-Schritt).
# - Das erzeugte Kommando-Skript dokumentiert transparent, welche Optionen beim
#   Installer verwendet werden.
# - Logging wird zentral an einem stabilen Ort abgelegt.
# -----------------------------------------------------------------------------

RUN_ID="${1:-}"
JUMP_GROUP="${2:-}"

if [[ -z "$RUN_ID" || -z "$JUMP_GROUP" ]]; then
  echo "Usage: $0 <runId> <jumpGroup>"
  exit 1
fi

check_connectivity() {
  # Prüft, ob das PRA-Zielsystem erreichbar ist, bevor Artefakte erzeugt werden.
  # Dadurch werden frühzeitige Fehler sichtbar (z. B. DNS/Firewall/Proxy-Probleme),
  # statt erst beim tatsächlichen Installer-Aufruf zu scheitern.
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

echo "Preparing BeyondTrust Jumpoint setup for RunId=${RUN_ID}, JumpGroup=${JUMP_GROUP}"
check_connectivity

install_root="/opt/beyondtrust/lab-bootstrap"
log_file="${install_root}/jumpoint-install.log"
cmd_file="${install_root}/install_jumpoint.sh"

sudo mkdir -p "$install_root"

cat <<EOF | sudo tee "$cmd_file" >/dev/null
#!/usr/bin/env bash
set -euo pipefail
# Der Installer wird absichtlich mit --quiet und --accept-eula gestartet,
# damit der Prozess vollständig ohne Benutzereingriff ausgeführt werden kann.
./BeyondTrustJumpoint.bin --quiet --accept-eula \\
  --run-id "${RUN_ID}" \\
  --jump-group "${JUMP_GROUP}" \\
  --bind-address "0.0.0.0" \\
  --register-service
EOF

sudo chmod 750 "$cmd_file"
echo "$(date -Iseconds) Prepared Jumpoint silent installation command in ${cmd_file}" | sudo tee -a "$log_file" >/dev/null

echo "Jumpoint preparation completed. Command script: ${cmd_file}"
