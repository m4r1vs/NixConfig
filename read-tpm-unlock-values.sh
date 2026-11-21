#!/usr/bin/env bash
# Reads the per-host values for configured.tpmUnlock (nixos-modules/tpm-unlock.nix)
# and writes them to ./tpm-unlock-values-<hostname>.nix. See TPM_HARDENINGS.md.
#
# Run as your normal user in a terminal: it uses sudo twice (swapfile offset,
# LUKS header copy) and asks for the disk passphrase once. The passphrase is
# never written anywhere; nothing gets opened, since a normal user has no
# device-mapper access.
#
# Usage: ./read-tpm-unlock-values.sh [mapping-name] [luks-device]
set -euo pipefail

mapping=${1:-cryptroot}
device=${2:-/dev/disk/by-partlabel/luks}
host=$(hostname)
out="$PWD/tpm-unlock-values-$host.nix"

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as your normal user, not as root (sudo is called where needed)." >&2
  exit 1
fi

tmp=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/tpm-unlock.XXXXXX")
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

# --- resume offset of the swapfile -------------------------------------------
swapfile=$(swapon --noheadings --raw --show=NAME,TYPE | awk '$2 == "file" { print $1; exit }')
offset=""
if [ -n "$swapfile" ]; then
  echo "Swapfile: $swapfile"
  offset=$(sudo btrfs inspect-internal map-swapfile -r "$swapfile")
  [[ "$offset" =~ ^[0-9]+$ ]] || { echo "Unexpected map-swapfile output: $offset" >&2; exit 1; }
else
  echo "No swapfile active; resumeOffset stays unset (the module adds noresume)."
fi

# --- volume key id ------------------------------------------------------------
sudo cryptsetup luksHeaderBackup "$device" --header-backup-file "$tmp/header.img"
sudo chown "$(id -u):$(id -g)" "$tmp/header.img"
chmod 600 "$tmp/header.img"

uuid=$(cryptsetup luksUUID "$tmp/header.img")

read -rsp "Disk passphrase for $device: " pw
echo
# A deliberately wrong pin makes systemd-cryptsetup print the real one
attach_out=$(printf '%s' "$pw" | systemd-cryptsetup attach "$mapping" "$tmp/header.img" /dev/stdin fixate-volume-key=0000 2>&1 || true)
unset pw

pin=$(printf '%s\n' "$attach_out" | sed -n "s/.*Volume key id: '\([0-9a-f]\{64\}\)' does not match.*/\1/p" | head -n1)
if [ -z "$pin" ]; then
  echo "Could not read the volume key id. systemd-cryptsetup said:" >&2
  printf '%s\n' "$attach_out" >&2
  exit 1
fi

# --- TPM token state (for the rollout check) -----------------------------------
meta=$(cryptsetup luksDump --dump-json-metadata "$tmp/header.img")
tpm_tokens=$(jq '[.tokens[] | select(.type == "systemd-tpm2")] | length' <<<"$meta")
tpm_pcrs=$(jq -c '[.tokens[] | select(.type == "systemd-tpm2") | ."tpm2-pcrs"]' <<<"$meta")
tpm_srk=$(jq '[.tokens[] | select(.type == "systemd-tpm2") | has("tpm2_srk")] | all' <<<"$meta")

# --- write the result -------------------------------------------------------------
{
  echo "# $host, read $(date -Iseconds) by read-tpm-unlock-values.sh"
  echo "# LUKS UUID: $uuid, mapping: $mapping, swapfile: ${swapfile:-none}"
  echo "# systemd-tpm2 tokens: $tpm_tokens, PCRs: $tpm_pcrs, all with tpm2_srk: $tpm_srk"
  echo "{"
  echo "  configured.tpmUnlock = {"
  echo "    volumeKeyId = \"$pin\";"
  [ -n "$offset" ] && echo "    resumeOffset = $offset;"
  echo "  };"
  echo "}"
} >"$out"

echo "Wrote $out:"
cat "$out"
