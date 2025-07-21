#!/bin/bash
set -e

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <aks-name> <aks-rg> <acr-name> <acr-rg> <repo1,repo2,...> <github-owner> [--reset]"
  exit 1
fi

AKS_NAME="$1"
AKS_RG="$2"
ACR_NAME="$3"
ACR_RG="$4"
REPO_NAMES_RAW="$5"
GITHUB_OWNER="$6"
RESET_FLAG="$7"


IFS=',' read -ra REPO_NAMES <<< "$REPO_NAMES_RAW"


RESET_SP="false"
if [[ "$RESET_FLAG" == "--reset" ]]; then
  RESET_SP="true"
fi


cat > terraform.tfvars <<EOF
aks_name_filter     = "$AKS_NAME"
aks_resource_group = "$AKS_RG"
acr_name           = "$ACR_NAME"
acr_resource_group = "$ACR_RG"
github_owner       = "$GITHUB_OWNER"
repo_names         = [${REPO_NAMES[@]@Q}]
reset_sp           = $RESET_SP
EOF


terraform apply -auto-approve

echo "✅ Update complete"