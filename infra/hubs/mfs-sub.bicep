// MFS Shared Subscription — Regional Hub Deployment
//
// Subscription-scoped deployment. Creates all resources for the
// Member Firm Shared (MFS) Foundry subscription in a given regional hub.
//
// Deployed resources:
//   rg-agentops-mfs-{hubRegion}
//     Log Analytics workspace + App Insights
//     Hub VNet (PE subnet + Foundry VNet injection subnet)
//     Key Vault, Storage, Cosmos DB, AI Search (shared services)
//     Foundry account (AIServices) with approved model deployments
//     Approved-models Azure Policy (deny non-approved models at RG scope)
//
//   Subscription scope:
//     Custom RBAC roles: Foundry Project User + Foundry Project Admin
//     Approved-models policy definition
//
// Usage:
//   az deployment sub create \
//     --location <location> \
//     --template-file infra/hubs/mfs-sub.bicep \
//     --parameters @infra/hubs/amr/mfs-sub.params.json \
//     --parameters costCenter=<value> environment=<value>

targetScope = 'subscription'

// ── Parameters ─────────────────────────────────────────────────────────────────

@description('Hub region: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Primary Azure region for resource deployment')
param location string

@description('VNet address space — e.g. 10.1.0.0/16')
param vnetAddressPrefix string

@description('Private endpoint subnet address prefix — e.g. 10.1.1.0/24')
param peSubnetAddressPrefix string

@description('Foundry VNet injection subnet address prefix — e.g. 10.1.2.0/24')
param vnetInjectionSubnetAddressPrefix string

@description('Approved model deployments for this hub. Each: { name, modelName, modelVersion, skuName, capacity }')
param approvedModelDeployments array

@description('Cost center code for billing tagging')
param costCenter string

@description('Deployment environment')
@allowed(['prod', 'uat', 'nonprod'])
param environment string = 'nonprod'

// ── Derived names (all deterministic from hubRegion) ──────────────────────────

var rgName = 'rg-agentops-mfs-${hubRegion}'
var foundryName = 'foundry-mfs-${hubRegion}'
var lawName = 'law-foundry-mfs-${hubRegion}'
var appInsightsName = 'ai-foundry-mfs-${hubRegion}'
var vnetName = 'vnet-foundry-mfs-${hubRegion}'
var kvName = 'kv-fndry-mfs-${hubRegion}'
var storageName = 'stfoundrymfs${hubRegion}001'
var cosmosName = 'cosmos-foundry-mfs-${hubRegion}'
var searchName = 'search-foundry-mfs-${hubRegion}'

var approvedModelNames = map(approvedModelDeployments, m => m.modelName)

var tags = {
  HubRegion: hubRegion
  SubscriptionTier: 'mfs'
  ManagedBy: 'foundry-platform'
  Environment: environment
  CostCenter: costCenter
}

// ── Resource Group ────────────────────────────────────────────────────────────
resource mfsRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: tags
}

// ── Custom RBAC Roles (subscription scope — one-time per subscription) ────────
// Creates 'Foundry Project User' and 'Foundry Project Admin' custom role
// definitions. Both have notActions blocking model deployment writes.
module rbacRoles '../modules/rbac/custom-roles.bicep' = {
  name: 'deploy-rbac-roles-mfs-${hubRegion}'
  scope: subscription()
}

// ── Monitoring ────────────────────────────────────────────────────────────────
module monitoring '../modules/monitoring/main.bicep' = {
  name: 'deploy-monitoring-mfs-${hubRegion}'
  scope: mfsRg
  params: {
    workspaceName: lawName
    appInsightsName: appInsightsName
    location: location
    hubRegion: hubRegion
    retentionDays: environment == 'prod' ? 90 : 30
    costCenter: costCenter
    environment: environment
  }
}

// ── Networking ────────────────────────────────────────────────────────────────
module networking '../modules/networking/main.bicep' = {
  name: 'deploy-networking-mfs-${hubRegion}'
  scope: mfsRg
  params: {
    vnetName: vnetName
    location: location
    hubRegion: hubRegion
    subscriptionTier: 'mfs'
    vnetAddressPrefix: vnetAddressPrefix
    peSubnetAddressPrefix: peSubnetAddressPrefix
    vnetInjectionSubnetAddressPrefix: vnetInjectionSubnetAddressPrefix
    costCenter: costCenter
    environment: environment
  }
}

// ── Shared Platform Services ──────────────────────────────────────────────────
module sharedServices '../modules/shared-services/main.bicep' = {
  name: 'deploy-shared-svc-mfs-${hubRegion}'
  scope: mfsRg
  params: {
    keyVaultName: kvName
    storageAccountName: storageName
    cosmosDbAccountName: cosmosName
    aiSearchName: searchName
    location: location
    hubRegion: hubRegion
    subscriptionTier: 'mfs'
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    peSubnetId: networking.outputs.peSubnetId
    costCenter: costCenter
    environment: environment
  }
}

// ── Foundry Instance ──────────────────────────────────────────────────────────
// POC: publicNetworkAccess = Enabled (subnetId empty).
// Prod: pass networking.outputs.peSubnetId to subnetId to enable private-only mode.
module foundry '../modules/foundry-instance/main.bicep' = {
  name: 'deploy-foundry-mfs-${hubRegion}'
  scope: mfsRg
  params: {
    instanceName: foundryName
    location: location
    hubRegion: hubRegion
    subscriptionTier: 'mfs'
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    // POC: leave subnetId empty for public access. For prod: networking.outputs.peSubnetId
    subnetId: environment == 'prod' ? networking.outputs.peSubnetId : ''
    approvedModelDeployments: approvedModelDeployments
    costCenter: costCenter
    environment: environment
  }
}

// ── Approved Models Policy — definition at subscription scope ─────────────────
resource approvedModelsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'foundry-approved-models-mfs-${hubRegion}'
  properties: {
    policyType: 'Custom'
    mode: 'All'
    displayName: 'MFS ${hubRegion} — Foundry approved model deployments only'
    description: 'Denies Foundry model deployments not in the hub-approved list. Managed by foundry-platform.'
    parameters: {}
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.CognitiveServices/accounts/deployments'
          }
          {
            field: 'Microsoft.CognitiveServices/accounts/deployments/model.name'
            notIn: approvedModelNames
          }
        ]
      }
      then: {
        effect: 'Deny'
      }
    }
  }
}

// Assign the policy at the Foundry RG scope
module approvedModelsPolicyAssignment '../policy/approved-models.bicep' = {
  name: 'assign-approved-models-mfs-${hubRegion}'
  scope: mfsRg
  params: {
    policyDefinitionId: approvedModelsPolicy.id
    assignmentDisplayName: 'MFS ${hubRegion} — approved model deployments only'
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output rgName string = rgName
output foundryId string = foundry.outputs.foundryId
output foundryName string = foundry.outputs.foundryName
output foundryEndpoint string = foundry.outputs.foundryEndpoint
output foundryPrincipalId string = foundry.outputs.foundryPrincipalId
output lawId string = monitoring.outputs.workspaceId
output vnetId string = networking.outputs.vnetId
output peSubnetId string = networking.outputs.peSubnetId
output keyVaultId string = sharedServices.outputs.keyVaultId
output cosmosDbEndpoint string = sharedServices.outputs.cosmosDbEndpoint
output aiSearchEndpoint string = sharedServices.outputs.aiSearchEndpoint
output projectUserRoleId string = rbacRoles.outputs.projectUserRoleId
output projectAdminRoleId string = rbacRoles.outputs.projectAdminRoleId
