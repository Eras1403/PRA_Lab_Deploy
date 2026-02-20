#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Dieses Skript installiert einen BeyondTrust Jump Client auf Linux und validiert
# anschließend, dass ein passender Systemdienst tatsächlich läuft.
#
# Ablauf auf hoher Ebene:
# 1) Eingaben prüfen (RunId/JumpGroup)
# 2) Erreichbarkeit des PRA-Endpunkts verifizieren
# 3) Installer ausführen (silent, machine scope)
# 4) Bekannte Service-Namen prüfen und Running-Status abwarten
# -----------------------------------------------------------------------------

RUN_ID="${1:-}"
JUMP_GROUP="${2:-}"

if [[ -z "$RUN_ID" || -z "$JUMP_GROUP" ]]; then
  echo "Usage: $0 <runId> <jumpGroup>"
  exit 1
fi

check_connectivity() {
  # Vorbedingung für sinnvolle Installation: Zielplattform muss erreichbar sein.
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

wait_for_service() {
  # Wartet robust auf den Start eines spezifischen Dienstes, da der Installer
  # den Service häufig asynchron initialisiert.
  local service_name="$1"
  local max_attempts=12
  local delay_seconds=5

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    if systemctl is-active --quiet "$service_name"; then
      echo "[Validation] Service '${service_name}' is running."
      return 0
    fi

    echo "[Validation] Waiting for service '${service_name}' (attempt ${attempt}/${max_attempts})"
    sleep "$delay_seconds"
  done

  return 1
}

echo "Preparing BeyondTrust Jump Client setup for RunId=${RUN_ID}, JumpGroup=${JUMP_GROUP}"
check_connectivity

installer="./BeyondTrustJumpClient.run"
if [[ ! -x "$installer" ]]; then
  # Wir verlangen explizit ein ausführbares Installer-Binary im aktuellen
  # Arbeitsverzeichnis. Das verhindert unklare Fehler in sudo/msiexec-ähnlichen
  # Subprozessen und liefert eine klare Fehlermeldung.
  echo "[Install] Installer '$installer' not found or not executable." >&2
  exit 1
fi

install_root="/opt/beyondtrust/lab-bootstrap"
log_file="${install_root}/jump-client-install.log"
service_candidates=(bomgar-jump-client bt-jump-client bomgar-scc)

sudo mkdir -p "$install_root"

install_cmd=(
  # --nox11 vermeidet GUI-Abhängigkeiten in Headless-/CI-Umgebungen.
  "$installer" --quiet --nox11 --accept-eula
  --run-id "$RUN_ID"
  --jump-group "$JUMP_GROUP"
  --install-scope machine
)

echo "[Install] Running Jump Client installer..."
sudo "${install_cmd[@]}" | sudo tee -a "$log_file"

echo "[Validation] Checking Jump Client service startup..."
for svc in "${service_candidates[@]}"; do
  if systemctl list-unit-files --type=service | awk '{print $1}' | grep -q "^${svc}\.service$"; then
    if wait_for_service "$svc"; then
      echo "Jump Client installation completed successfully."
      exit 0
    fi
  fi
done

echo "[Validation] Unable to verify running Jump Client service. Checked: ${service_candidates[*]}" >&2
sudo systemctl --no-pager --type=service --state=running | grep -Ei 'bomgar|beyondtrust|jump' || true
exit 1
