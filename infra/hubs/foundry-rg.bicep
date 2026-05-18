// Foundry Resource Group Deployment — Single Tier
//
// Resource-group-scoped template. Deploys one complete Foundry instance
// with monitoring, networking, shared services, and approved-model policy
// for a given hub + tier combination.
//
// All 13 Foundry RGs (mfs, gf-audit, gf-advisory, gf-tax, g9-us, g9-ca,
// g9-uk, g9-de, g9-fr, g9-nl, g9-au, g9-jp, g9-cn) use this same template.
//
// The resource group must be pre-created before this deployment.
// Custom RBAC roles are deployed once at subscription scope by the workflow.
//
// Usage:
//   az deployment group create \
//     --resource-group rg-agentops-{tier}-{hub} \
//     --template-file infra/hubs/foundry-rg.bicep \
//     --parameters hub=amr tier=mfs location=eastus2 \
//                  vnetAddressPrefix=10.1.0.0/22 \
//                  peSubnetAddressPrefix=10.1.0.0/24 \
//                  vnetInjectionSubnetAddressPrefix=10.1.1.0/24 \
//                  approvedModelDeployments=@infra/hubs/amr/models.json \
//                  costCenter=135355 environment=dev

targetScope = 'resourceGroup'

// ── Parameters ─────────────────────────────────────────────────────────────────

@description('Hub region: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hub string

@description('Foundry tier identifier — e.g. mfs, gf-tax, g9-us')
param tier string

@description('Primary Azure region for resource deployment')
param location string

@description('VNet address space — e.g. 10.1.0.0/22')
param vnetAddressPrefix string

@description('Private endpoint subnet address prefix — e.g. 10.1.0.0/24')
param peSubnetAddressPrefix string

@description('Foundry VNet injection subnet address prefix — e.g. 10.1.1.0/24')
param vnetInjectionSubnetAddressPrefix string

@description('Approved model deployments. Each item: { name, modelName, modelVersion, skuName, capacity }')
param approvedModelDeployments array

@description('Cost center code for billing tags')
param costCenter string

@description('Deployment environment')
@allowed(['prod', 'uat', 'nonprod'])
param environment string = 'nonprod'

// ── Derived resource names ────────────────────────────────────────────────────

var safeHub  = replace(hub, '-', '')
var safeTier = replace(tier, '-', '')

var foundryName    = 'foundry-${tier}-${hub}'
var lawName        = 'law-foundry-${tier}-${hub}'
var appInsightsName = 'ai-foundry-${tier}-${hub}'
var vnetName       = 'vnet-foundry-${tier}-${hub}'
var kvName         = 'kv-fndry-${safeTier}-${safeHub}'
var storageName    = 'stfoundry${safeTier}${safeHub}001'
var cosmosName     = 'cosmos-foundry-${tier}-${hub}'
var searchName     = 'search-foundry-${tier}-${hub}'

var approvedModelNames = map(approvedModelDeployments, m => m.modelName)

// ── Monitoring ────────────────────────────────────────────────────────────────
module monitoring '../modules/monitoring/main.bicep' = {
  name: 'deploy-monitoring-${tier}-${hub}'
  params: {
    workspaceName   : lawName
    appInsightsName : appInsightsName
    location        : location
    hubRegion       : hub
    retentionDays   : environment == 'prod' ? 90 : 30
    costCenter      : costCenter
    environment     : environment
  }
}

// ── Networking ────────────────────────────────────────────────────────────────
module networking '../modules/networking/main.bicep' = {
  name: 'deploy-networking-${tier}-${hub}'
  params: {
    vnetName                          : vnetName
    location                          : location
    hubRegion                         : hub
    subscriptionTier                  : tier
    vnetAddressPrefix                 : vnetAddressPrefix
    peSubnetAddressPrefix             : peSubnetAddressPrefix
    vnetInjectionSubnetAddressPrefix  : vnetInjectionSubnetAddressPrefix
    costCenter                        : costCenter
    environment                       : environment
  }
}

// ── Shared Platform Services ──────────────────────────────────────────────────
module sharedServices '../modules/shared-services/main.bicep' = {
  name: 'deploy-shared-svc-${tier}-${hub}'
  params: {
    keyVaultName              : kvName
    storageAccountName        : storageName
    cosmosDbAccountName       : cosmosName
    aiSearchName              : searchName
    location                  : location
    hubRegion                 : hub
    subscriptionTier          : tier
    logAnalyticsWorkspaceId   : monitoring.outputs.workspaceId
    peSubnetId                : networking.outputs.peSubnetId
    costCenter                : costCenter
    environment               : environment
  }
}

// ── Foundry Instance ──────────────────────────────────────────────────────────
module foundry '../modules/foundry-instance/main.bicep' = {
  name: 'deploy-foundry-${tier}-${hub}'
  params: {
    instanceName              : foundryName
    location                  : location
    hubRegion                 : hub
    subscriptionTier          : tier
    logAnalyticsWorkspaceId   : monitoring.outputs.workspaceId
    subnetId                  : environment == 'prod' ? networking.outputs.peSubnetId : ''
    approvedModelDeployments  : approvedModelDeployments
    costCenter                : costCenter
    environment               : environment
  }
}

// ── Approved Models Policy definition (RG scope for POC) ─────────────────────
resource approvedModelsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'foundry-approved-models-${tier}-${hub}'
  scope: subscription()
}

module approvedModelsPolicyAssignment '../policy/approved-models.bicep' = {
  name: 'assign-approved-models-${tier}-${hub}'
  params: {
    policyDefinitionId    : approvedModelsPolicy.id
    assignmentDisplayName : '${tier} ${hub} — approved model deployments only'
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output foundryId          string = foundry.outputs.foundryId
output foundryName        string = foundry.outputs.foundryName
output foundryEndpoint    string = foundry.outputs.foundryEndpoint
output foundryPrincipalId string = foundry.outputs.foundryPrincipalId
output lawId              string = monitoring.outputs.workspaceId
output vnetId             string = networking.outputs.vnetId
output peSubnetId         string = networking.outputs.peSubnetId
output keyVaultId         string = sharedServices.outputs.keyVaultId
