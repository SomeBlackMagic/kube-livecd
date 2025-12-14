#!/bin/sh
set -eu

# =========================
# Input parameters
# =========================
# $1 — major.minor (For example: 1.29)
# $2 — full version (For example: v1.29.7)

MAJOR_MINOR="${1:?major.minor is required (e.g. 1.29)}"
K8S_FULL_VERSION="${2:?full k8s version is required (e.g. v1.29.7)}"

CONFIG_FILE=".github/k8s-arg-list.yaml"

# =========================
# verification
# =========================
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: resolver config not found: $CONFIG_FILE" >&2
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq (v4+) is required" >&2
  exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "ERROR: envsubst is required (gettext-base)" >&2
  exit 1
fi

# =========================
# Exporting Template Variables
# =========================
export K8S_FULL_VERSION

# =========================
# Checking for version availability in YAML
# =========================
if ! yq -e ".resolver[\"$MAJOR_MINOR\"]" "$CONFIG_FILE" >/dev/null; then
  echo "ERROR: resolver for version '$MAJOR_MINOR' not found in $CONFIG_FILE" >&2
  exit 1
fi

# =========================
# RESOLVING
# =========================
yq -r ".resolver[\"$MAJOR_MINOR\"] | to_entries | .[] | \"\(.key)=\(.value)\"" "$CONFIG_FILE" \
  | envsubst
