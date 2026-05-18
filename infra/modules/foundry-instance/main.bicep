// Microsoft Foundry V2 — Foundry Account (CognitiveServices/accounts kind:AIServices)
//
// Deployed once per subscription-tier per region:
//   - foundry-mfs-{region}  in MFS Shared Subscription
//   - foundry-tax-{region}  in Global Function Tax Subscription
//
// Resource model (Foundry V2):
//   Microsoft.CognitiveServices/accounts (kind:AIServices)   ← Foundry resource
//     └── Microsoft.CognitiveServices/accounts/projects       ← child project
//     └── Microsoft.CognitiveServices/accounts/deployments    ← model deployments (account-level)
//
// Custom roles that prevent project-level users from touching deployments are
// defined in infra/modules/rbac/custom-roles.bicep and deployed at subscription scope.

@description('Foundry account name — e.g. foundry-mfs-amr')
param instanceName string

@description('Azure region — e.g. eastus2, westeurope, southeastasia')
param location string

@description('Hub region code used for tagging and naming: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Subscription tier: mfs | tax')
@allowed(['mfs', 'tax'])
param subscriptionTier string

@description('Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('VNet subnet resource ID for private endpoint — leave empty for public dev access')
param subnetId string = ''

@description('Approved model deployments for this hub. Each: { name, modelName, modelVersion, skuName, capacity }')
param approvedModelDeployments array

@description('Cost center code for billing tagging')
param costCenter string

@description('Data classification: Public | Internal | Confidential | Restricted')
@allowed(['Public', 'Internal', 'Confidential', 'Restricted'])
param dataClassification string = 'Internal'

@description('Deployment environment')
@allowed(['prod', 'uat', 'nonprod'])
param environment string = 'nonprod'

var tags = {
  FoundryInstance: instanceName
  HubRegion: hubRegion
  SubscriptionTier: subscriptionTier
  ManagedBy: 'foundry-platform'
  Environment: environment
  CostCenter: costCenter
  DataClassification: dataClassification
}

// ── Foundry account (Foundry V2) ─────────────────────────────────────────────
resource foundryAccount 'Microsoft.CognitiveServices/accounts@2026-03-01' = {
  name: instanceName
  location: location
  kind: 'AIServices'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: instanceName
    disableLocalAuth: true                 // Entra ID only — no API keys
    publicNetworkAccess: (environment == 'prod' && !empty(subnetId)) ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: (environment == 'prod' && !empty(subnetId)) ? 'Deny' : 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// ── Default project — used for platform admin tooling and initial connectivity ──
resource defaultProject 'Microsoft.CognitiveServices/accounts/projects@2026-03-01' = {
  parent: foundryAccount
  name: 'platform-default'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Platform Default (${subscriptionTier}-${hubRegion})'
    description: 'Platform-managed default project for ${instanceName}. Not for workload use.'
  }
}

// ── Model deployments from the hub-approved list ─────────────────────────────
// Models deployed here are shared across all vended projects on this account.
// Project-level users cannot deploy additional models (enforced via custom RBAC notActions
// and the Azure Policy in infra/policy/deny-model-provisioning.json).
@batchSize(1)
resource approvedDeployments 'Microsoft.CognitiveServices/accounts/deployments@2026-03-01' = [for model in approvedModelDeployments: {
  parent: foundryAccount
  name: model.name
  sku: {
    name: model.skuName
    capacity: model.capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: model.modelName
      version: model.modelVersion
    }
  }
  dependsOn: [defaultProject]
}]

// ── Private endpoint (prod only) ─────────────────────────────────────────────
// dependsOn ensures account + all child resources reach Succeeded before PE creation.
// Creating a PE concurrently with child resources causes AccountProvisioningStateInvalid.
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!empty(subnetId)) {
  name: 'pe-${instanceName}'
  location: location
  tags: tags
  dependsOn: [
    defaultProject
    approvedDeployments
  ]
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${instanceName}'
        properties: {
          privateLinkServiceId: foundryAccount.id
          groupIds: ['account']
        }
      }
    ]
  }
}

// ── Diagnostics → regional Log Analytics workspace ───────────────────────────
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${instanceName}'
  scope: foundryAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { categoryGroup: 'allLogs'; enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'; enabled: true }
    ]
  }
}

output foundryId string = foundryAccount.id
output foundryName string = foundryAccount.name
output foundryEndpoint string = foundryAccount.properties.endpoint
output foundryPrincipalId string = foundryAccount.identity.principalId
output defaultProjectId string = defaultProject.id
output defaultProjectName string = defaultProject.name
output defaultProjectEndpoint string = '${foundryAccount.properties.endpoint}api/projects/${defaultProject.name}'
output deployedModelNames array = [for (model, i) in approvedModelDeployments: approvedDeployments[i].name]
