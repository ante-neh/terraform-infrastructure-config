#!/bin/bash
set -e


export PATH=$PATH:/usr/bin:/usr/local/bin:/opt/homebrew/bin


if ! command -v az &> /dev/null; then
    echo "⚠️  Azure CLI not found. Please install it for better management: https://aka.ms/install-azure-cli"
fi


if [[ $# -lt 6 ]]; then
  echo "❌ Usage: $0 <aks-name> <aks-rg> <acr-name> <acr-rg> <repo1,repo2,...> <github-owner> [--reset]"
  exit 1
fi

AKS_NAME="$1"
AKS_RG="$2"
ACR_NAME="$3"
ACR_RG="$4"
REPO_NAMES_RAW="$5"
GITHUB_OWNER="$6"
RESET_FLAG="${7:-}"


IFS=',' read -ra REPO_NAMES <<< "$REPO_NAMES_RAW"


RESET_SP="false"
if [[ "$RESET_FLAG" == "--reset" ]]; then
  RESET_SP="true"
fi


REPO_LIST="["
for repo in "${REPO_NAMES[@]}"; do
  REPO_LIST+="\"$repo\", "
done
REPO_LIST="${REPO_LIST%, }]"


mkdir -p env_files


for repo in "${REPO_NAMES[@]}"; do
  ENV_FILE="env_files/.env.$repo"
  if [ ! -f "$ENV_FILE" ]; then
    echo "# Environment variables for $repo" > "$ENV_FILE"
    echo "PORT=8080" >> "$ENV_FILE"
    echo "NODE_ENV=production" >> "$ENV_FILE"
    echo "# Add more variables as needed" >> "$ENV_FILE"
    echo "✅ Created default environment file: $ENV_FILE"
  fi
done


cat > terraform.tfvars <<EOF
aks_name_filter     = "$AKS_NAME"
aks_resource_group  = "$AKS_RG"
acr_name            = "$ACR_NAME"
acr_resource_group  = "$ACR_RG"
github_owner        = "$GITHUB_OWNER"
repo_names          = $REPO_LIST
reset_sp            = $RESET_SP
EOF

terraform init
terraform apply -auto-approve

echo ""
echo "✅ Bootstrap complete"
echo "📁 Environment files:"
for repo in "${REPO_NAMES[@]}"; do
  echo "  - env_files/.env.$repo"
done
echo "ℹ️  Edit these files to customize environment variables for each repository"