#!/usr/bin/env bash
# bootstrap-hub.sh — One-shot bootstrap for a regional Foundry hub
#
# Run this ONCE before the first deploy-hub.yml execution to set up:
#   1. Federated OIDC credentials (one app registration per subscription per hub)
#   2. GitHub Environments and secrets via the gh CLI
#   3. Required Azure resource providers (subscription-level registration)
#   4. Azure RBAC for the platform service principals
#
# Prerequisites:
#   - az CLI logged in with Owner on all 3 subscriptions
#   - gh CLI authenticated with admin access to the GitHub repo
#   - jq installed
#
# Usage:
#   ./scripts/bootstrap-hub.sh \
#     --hub amr \
#     --tenant-id <tenant-id> \
#     --sub-mfs <mfs-subscription-id> \
#     --sub-tax <tax-subscription-id> \
#     --sub-shared <shared-subscription-id> \
#     --repo <org/repo> \
#     --publisher-email <email>

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
HUB=""
TENANT_ID=""
SUB_MFS=""
SUB_TAX=""
SUB_SHARED=""
GH_REPO=""
PUBLISHER_EMAIL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --hub)               HUB="$2";              shift 2 ;;
    --tenant-id)         TENANT_ID="$2";         shift 2 ;;
    --sub-mfs)           SUB_MFS="$2";           shift 2 ;;
    --sub-tax)           SUB_TAX="$2";           shift 2 ;;
    --sub-shared)        SUB_SHARED="$2";        shift 2 ;;
    --repo)              GH_REPO="$2";           shift 2 ;;
    --publisher-email)   PUBLISHER_EMAIL="$2";   shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# Validate required args
for VAR in HUB TENANT_ID SUB_MFS SUB_TAX SUB_SHARED GH_REPO PUBLISHER_EMAIL; do
  if [ -z "${!VAR}" ]; then
    echo "ERROR: --$(echo $VAR | tr '[:upper:]' '[:lower:]' | tr '_' '-') is required"
    exit 1
  fi
done

if [[ ! "$HUB" =~ ^(amr|emea|apac)$ ]]; then
  echo "ERROR: --hub must be amr, emea, or apac"
  exit 1
fi

echo "=== Foundry Hub Bootstrap: $HUB ==="
echo "Tenant: $TENANT_ID"
echo "Subscriptions: MFS=$SUB_MFS | Tax=$SUB_TAX | Shared=$SUB_SHARED"
echo "GitHub repo: $GH_REPO"
echo ""

# ── Helper functions ──────────────────────────────────────────────────────────
register_providers() {
  local SUB_ID="$1"
  echo "Registering required resource providers in subscription $SUB_ID..."
  az account set --subscription "$SUB_ID"
  for PROVIDER in \
    Microsoft.CognitiveServices \
    Microsoft.ApiManagement \
    Microsoft.Network \
    Microsoft.KeyVault \
    Microsoft.Storage \
    Microsoft.DocumentDB \
    Microsoft.Search \
    Microsoft.OperationalInsights \
    Microsoft.Insights \
    Microsoft.Authorization \
    ; do
    az provider register --namespace "$PROVIDER" --wait --output none 2>/dev/null || true
    echo "  ✓ $PROVIDER"
  done
}

create_oidc_app() {
  local NAME="$1"
  local SUB_ID="$2"
  local ENV_NAME="$3"

  echo "Creating app registration: $NAME ..."
  APP_ID=$(az ad app create --display-name "$NAME" --query appId -o tsv)
  SP_OID=$(az ad sp create --id "$APP_ID" --query id -o tsv)

  # Owner on subscription (needed for resource group creation + policy definitions)
  az role assignment create \
    --assignee-object-id "$SP_OID" \
    --assignee-principal-type ServicePrincipal \
    --role "Owner" \
    --scope "/subscriptions/$SUB_ID" \
    --output none

  # Federated credential for GitHub Actions
  az ad app federated-credential create \
    --id "$APP_ID" \
    --parameters "{
      \"name\": \"github-${ENV_NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"repo:${GH_REPO}:environment:${ENV_NAME}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" \
    --output none

  echo "  ✓ App: $NAME | Client ID: $APP_ID | SP OID: $SP_OID"
  echo "$APP_ID"
}

create_gh_environment() {
  local ENV_NAME="$1"
  local CLIENT_ID="$2"
  local SUB_ID="$3"

  echo "Creating GitHub environment: $ENV_NAME ..."
  gh api \
    --method PUT \
    "repos/$GH_REPO/environments/$ENV_NAME" \
    --field "wait_timer=0" \
    --silent 2>/dev/null || true

  gh secret set AZURE_CLIENT_ID      --env "$ENV_NAME" --body "$CLIENT_ID"  --repo "$GH_REPO"
  gh secret set AZURE_SUBSCRIPTION_ID --env "$ENV_NAME" --body "$SUB_ID"   --repo "$GH_REPO"
  echo "  ✓ Environment secrets set for $ENV_NAME"
}

# ── Step 1: Register resource providers ──────────────────────────────────────
echo "--- Step 1: Register resource providers ---"
register_providers "$SUB_MFS"
register_providers "$SUB_TAX"
register_providers "$SUB_SHARED"

# ── Step 2: Create OIDC app registrations (one per subscription per hub) ──────
echo ""
echo "--- Step 2: Create OIDC app registrations ---"

CLIENT_ID_MFS=$(create_oidc_app    "sp-foundry-${HUB}-mfs"    "$SUB_MFS"    "${HUB}-mfs")
CLIENT_ID_TAX=$(create_oidc_app    "sp-foundry-${HUB}-tax"    "$SUB_TAX"    "${HUB}-tax")
CLIENT_ID_SHARED=$(create_oidc_app "sp-foundry-${HUB}-shared" "$SUB_SHARED" "${HUB}-shared")

# ── Step 3: Create GitHub environments and set secrets ────────────────────────
echo ""
echo "--- Step 3: Create GitHub environments ---"

create_gh_environment "${HUB}-mfs"    "$CLIENT_ID_MFS"    "$SUB_MFS"
create_gh_environment "${HUB}-tax"    "$CLIENT_ID_TAX"    "$SUB_TAX"
create_gh_environment "${HUB}-shared" "$CLIENT_ID_SHARED" "$SUB_SHARED"

# Set cross-subscription IDs on the shared environment
# (needed by deploy-hub.yml to grant APIM MI role on Foundry accounts in other subs)
gh secret set AZURE_SUBSCRIPTION_ID_MFS --env "${HUB}-shared" --body "$SUB_MFS"   --repo "$GH_REPO"
gh secret set AZURE_SUBSCRIPTION_ID_TAX --env "${HUB}-shared" --body "$SUB_TAX"   --repo "$GH_REPO"

# ── Step 4: Set common repo-level secrets (idempotent) ───────────────────────
echo ""
echo "--- Step 4: Set common repo-level secrets ---"

gh secret set AZURE_TENANT_ID        --body "$TENANT_ID"        --repo "$GH_REPO" 2>/dev/null || true
gh secret set APIM_PUBLISHER_EMAIL   --body "$PUBLISHER_EMAIL"  --repo "$GH_REPO" 2>/dev/null || true

# ── Step 5: Update shared-services params with tenant ID and email ─────────────
echo ""
echo "--- Step 5: Update shared-services params ---"

PARAMS_FILE="infra/hubs/${HUB}/shared-services-sub.params.json"
if [ -f "$PARAMS_FILE" ]; then
  UPDATED=$(jq \
    --arg tid "$TENANT_ID" \
    --arg email "$PUBLISHER_EMAIL" \
    '.parameters.entraIdTenantId.value = $tid | .parameters.publisherEmail.value = $email' \
    "$PARAMS_FILE")
  echo "$UPDATED" > "$PARAMS_FILE"
  echo "  ✓ Updated $PARAMS_FILE"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Summary:"
echo "  Hub:                 $HUB"
echo "  MFS Client ID:       $CLIENT_ID_MFS"
echo "  Tax Client ID:       $CLIENT_ID_TAX"
echo "  Shared Client ID:    $CLIENT_ID_SHARED"
echo ""
echo "Next steps:"
echo "  1. Commit the updated infra/hubs/${HUB}/shared-services-sub.params.json"
echo "  2. Update infra/hubs/${HUB}/mfs-sub.params.json and tax-sub.params.json"
echo "     to set the correct costCenter value"
echo "  3. Run the 'Deploy Regional Hub' GitHub Actions workflow for hub: $HUB"
echo ""
echo "Tip: Run with --hub emea and --hub apac to bootstrap the remaining hubs."
