// Global Function Tax Subscription — Regional Hub Deployment
//
// Subscription-scoped deployment. Creates all resources for the
// Global Function Tax Foundry subscription in a given regional hub.
//
// Structurally identical to mfs-sub.bicep with subscriptionTier='tax'
// and different naming conventions.
//
// Usage:
//   az deployment sub create \
//     --location <location> \
//     --template-file infra/hubs/tax-sub.bicep \
//     --parameters @infra/hubs/amr/tax-sub.params.json \
//     --parameters costCenter=<value> environment=<value>

targetScope = 'subscription'

// ── Parameters ─────────────────────────────────────────────────────────────────

@description('Hub region: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Primary Azure region for resource deployment')
param location string

@description('VNet address space — e.g. 10.1.16.0/20')
param vnetAddressPrefix string

@description('Private endpoint subnet address prefix — e.g. 10.1.17.0/24')
param peSubnetAddressPrefix string

@description('Foundry VNet injection subnet address prefix — e.g. 10.1.18.0/24')
param vnetInjectionSubnetAddressPrefix string

@description('Approved model deployments for this hub. Each: { name, modelName, modelVersion, skuName, capacity }')
param approvedModelDeployments array

@description('Cost center code for billing tagging')
param costCenter string

@description('Deployment environment')
@allowed(['prod', 'staging', 'dev'])
param environment string = 'prod'

// ── Derived names ─────────────────────────────────────────────────────────────

var rgName = 'rg-foundry-tax-${hubRegion}'
var foundryName = 'foundry-tax-${hubRegion}'
var lawName = 'law-foundry-tax-${hubRegion}'
var appInsightsName = 'ai-foundry-tax-${hubRegion}'
var vnetName = 'vnet-foundry-tax-${hubRegion}'
var kvName = 'kv-fndry-tax-${hubRegion}'
var storageName = 'stfoundrytax${hubRegion}001'
var cosmosName = 'cosmos-foundry-tax-${hubRegion}'
var searchName = 'search-foundry-tax-${hubRegion}'

var approvedModelNames = map(approvedModelDeployments, m => m.modelName)

var tags = {
  HubRegion: hubRegion
  SubscriptionTier: 'tax'
  ManagedBy: 'foundry-platform'
  Environment: environment
  CostCenter: costCenter
}

// ── Resource Group ────────────────────────────────────────────────────────────
resource taxRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: tags
}

// ── Custom RBAC Roles (subscription scope) ────────────────────────────────────
module rbacRoles '../modules/rbac/custom-roles.bicep' = {
  name: 'deploy-rbac-roles-tax-${hubRegion}'
  scope: subscription()
}

// ── Monitoring ────────────────────────────────────────────────────────────────
module monitoring '../modules/monitoring/main.bicep' = {
  name: 'deploy-monitoring-tax-${hubRegion}'
  scope: taxRg
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
  name: 'deploy-networking-tax-${hubRegion}'
  scope: taxRg
  params: {
    vnetName: vnetName
    location: location
    hubRegion: hubRegion
    subscriptionTier: 'tax'
    vnetAddressPrefix: vnetAddressPrefix
    peSubnetAddressPrefix: peSubnetAddressPrefix
    vnetInjectionSubnetAddressPrefix: vnetInjectionSubnetAddressPrefix
    costCenter: costCenter
    environment: environment
  }
}

// ── Shared Platform Services ──────────────────────────────────────────────────
module sharedServices '../modules/shared-services/main.bicep' = {
  name: 'deploy-shared-svc-tax-${hubRegion}'
  scope: taxRg
  params: {
    keyVaultName: kvName
    storageAccountName: storageName
    cosmosDbAccountName: cosmosName
    aiSearchName: searchName
    location: location
    hubRegion: hubRegion
    subscriptionTier: 'tax'
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    peSubnetId: networking.outputs.peSubnetId
    costCenter: costCenter
    environment: environment
  }
}

// ── Foundry Instance ──────────────────────────────────────────────────────────
module foundry '../modules/foundry-instance/main.bicep' = {
  name: 'deploy-foundry-tax-${hubRegion}'
  scope: taxRg
  params: {
    instanceName: foundryName
    location: location
    hubRegion: hubRegion
    subscriptionTier: 'tax'
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    subnetId: environment == 'prod' ? networking.outputs.peSubnetId : ''
    approvedModelDeployments: approvedModelDeployments
    costCenter: costCenter
    environment: environment
  }
}

// ── Approved Models Policy ────────────────────────────────────────────────────
resource approvedModelsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'foundry-approved-models-tax-${hubRegion}'
  properties: {
    policyType: 'Custom'
    mode: 'All'
    displayName: 'Tax ${hubRegion} — Foundry approved model deployments only'
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

module approvedModelsPolicyAssignment '../policy/approved-models.bicep' = {
  name: 'assign-approved-models-tax-${hubRegion}'
  scope: taxRg
  params: {
    policyDefinitionId: approvedModelsPolicy.id
    assignmentDisplayName: 'Tax ${hubRegion} — approved model deployments only'
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
