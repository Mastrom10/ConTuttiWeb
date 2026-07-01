#!/usr/bin/env bash
set -euo pipefail

AWS="${AWS:-$HOME/.local/bin/aws}"
export AWS_PROFILE="${AWS_PROFILE:-contutti}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

LEGACY_ZONE_ID="Z05204692GY3U9JKMQ795"

log() { echo "[cleanup] $*"; }

cleanup_lightsail() {
  log "Buscando recursos Lightsail..."
  local instances
  instances=$("$AWS" lightsail get-instances --query 'instances[].name' --output text 2>/dev/null || true)
  if [ -n "$instances" ] && [ "$instances" != "None" ]; then
    for name in $instances; do
      log "Eliminando instancia Lightsail: $name"
      "$AWS" lightsail delete-instance --instance-name "$name" --force-delete-add-ons >/dev/null
    done
  else
    log "No hay instancias Lightsail en esta cuenta."
  fi

  local static_ips
  static_ips=$("$AWS" lightsail get-static-ips --query 'staticIps[].name' --output text 2>/dev/null || true)
  if [ -n "$static_ips" ] && [ "$static_ips" != "None" ]; then
    for ip in $static_ips; do
      log "Liberando static IP Lightsail: $ip"
      "$AWS" lightsail release-static-ip --static-ip-name "$ip" >/dev/null 2>&1 || true
      "$AWS" lightsail delete-static-ip --static-ip-name "$ip" >/dev/null 2>&1 || true
    done
  fi

  local snapshots
  snapshots=$("$AWS" lightsail get-instance-snapshots --query 'instanceSnapshots[].name' --output text 2>/dev/null || true)
  if [ -n "$snapshots" ] && [ "$snapshots" != "None" ]; then
    for snap in $snapshots; do
      log "Eliminando snapshot: $snap"
      "$AWS" lightsail delete-instance-snapshot --instance-snapshot-name "$snap" >/dev/null
    done
  fi
}

delete_legacy_hosted_zone() {
  log "Eliminando hosted zone legacy contutti.com.ar (${LEGACY_ZONE_ID})"
  local records
  records=$("$AWS" route53 list-resource-record-sets --hosted-zone-id "$LEGACY_ZONE_ID" --output json)

  LEGACY_ZONE_ID="$LEGACY_ZONE_ID" AWS="$AWS" AWS_PROFILE="$AWS_PROFILE" \
    RECORDS_JSON="$records" python3 <<'PY'
import json, os, subprocess

data = json.loads(os.environ["RECORDS_JSON"])
aws = os.environ["AWS"]
profile = os.environ["AWS_PROFILE"]
zone = os.environ["LEGACY_ZONE_ID"]

changes = []
for rr in data["ResourceRecordSets"]:
    if rr["Type"] in ("NS", "SOA"):
        continue
    changes.append({"Action": "DELETE", "ResourceRecordSet": rr})

if changes:
    batch = {"Comment": "Delete legacy records", "Changes": changes}
    path = "/tmp/delete-legacy-records.json"
    with open(path, "w") as f:
        json.dump(batch, f)
    subprocess.run([
        aws, "route53", "change-resource-record-sets",
        "--hosted-zone-id", zone,
        "--change-batch", f"file://{path}",
        "--profile", profile,
    ], check=True)
PY

  "$AWS" route53 delete-hosted-zone --id "$LEGACY_ZONE_ID"
  log "Hosted zone contutti.com.ar eliminada."
}

cleanup_lightsail
export LEGACY_ZONE_ID
delete_legacy_hosted_zone
log "Limpieza completada."
