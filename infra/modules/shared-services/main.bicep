// Shared Platform Services Module
//
// Deploys the platform-level data services shared across all Foundry projects
// within a subscription tier (mfs or tax). These resources are provisioned
// once per Foundry subscription and accessed by Foundry projects via
// project-scoped managed identity with least-privilege RBAC.
//
// Resources:
//   Key Vault    — secrets, API keys, certificates for agents
//   Storage      — blob storage for agent files, evaluation datasets, artefacts
//   Cosmos DB    — conversation history and agent state storage
//   AI Search    — RAG grounding index for Foundry projects
//
// Access pattern:
//   Foundry project managed identities are granted:
//     Key Vault  → Key Vault Secrets User
//     Storage    → Storage Blob Data Contributor (project-scoped container)
//     Cosmos DB  → Cosmos DB Built-in Data Contributor
//     AI Search  → Search Index Data Contributor
//   via role assignments in the foundry-project module.

@description('Key Vault name — must be globally unique, 3-24 chars')
param keyVaultName string

@description('Storage account name — must be globally unique, 3-24 lowercase chars')
param storageAccountName string

@description('Cosmos DB account name — must be globally unique')
param cosmosDbAccountName string

@description('AI Search service name — must be globally unique')
param aiSearchName string

@description('Azure region')
param location string

@description('Hub region code: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Subscription tier: mfs | tax')
@allowed(['mfs', 'gf-audit', 'gf-advisory', 'gf-tax', 'g9-us', 'g9-ca', 'g9-uk', 'g9-de', 'g9-fr', 'g9-nl', 'g9-au', 'g9-jp', 'g9-cn'])
param subscriptionTier string

@description('Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Private endpoint subnet ID — leave empty for POC public access')
param peSubnetId string = ''

@description('Cost center code for tagging')
param costCenter string

@description('Deployment environment')
@allowed(['prod', 'uat', 'nonprod'])
param environment string = 'nonprod'

var tags = {
  HubRegion: hubRegion
  SubscriptionTier: subscriptionTier
  ManagedBy: 'foundry-platform'
  Environment: environment
  CostCenter: costCenter
}

var isPrivate = !empty(peSubnetId) && environment == 'prod'

// ── Key Vault ─────────────────────────────────────────────────────────────────
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: environment == 'prod' ? 90 : 30
    enablePurgeProtection: environment == 'prod' ? true : null
    publicNetworkAccess: isPrivate ? 'Disabled' : 'Enabled'
    networkAcls: isPrivate ? {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    } : {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource kvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${keyVaultName}'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// ── Key Vault Private Endpoint (prod only) ────────────────────────────────────
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (isPrivate) {
  name: 'pe-${keyVaultName}'
  location: location
  tags: tags
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${keyVaultName}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

// ── Storage Account ───────────────────────────────────────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: environment == 'prod' ? 'Standard_ZRS' : 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: isPrivate ? 'Disabled' : 'Enabled'
    networkAcls: isPrivate ? {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    } : {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${storageAccountName}'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [{ category: 'Transaction', enabled: true }]
  }
}

// ── Storage Private Endpoint (prod only) ──────────────────────────────────────
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (isPrivate) {
  name: 'pe-${storageAccountName}-blob'
  location: location
  tags: tags
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${storageAccountName}-blob'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

// ── Cosmos DB (agent state + conversation history) ────────────────────────────
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: cosmosDbAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: environment == 'prod'
      }
    ]
    disableLocalAuth: true
    publicNetworkAccess: isPrivate ? 'Disabled' : 'Enabled'
    isVirtualNetworkFilterEnabled: false
    minimalTlsVersion: 'Tls12'
  }
}

resource cosmosDb_database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosDb
  name: 'foundry-platform'
  properties: {
    resource: { id: 'foundry-platform' }
  }
}

resource cosmosDb_agentStateContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = {
  parent: cosmosDb_database
  name: 'agent-state'
  properties: {
    resource: {
      id: 'agent-state'
      partitionKey: {
        paths: ['/projectId']
        kind: 'Hash'
      }
      defaultTtl: environment == 'prod' ? 2592000 : 604800
    }
  }
}

resource cosmosDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${cosmosDbAccountName}'
  scope: cosmosDb
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    metrics: [{ category: 'Requests', enabled: true }]
  }
}

// ── AI Search (RAG grounding index) ──────────────────────────────────────────
resource aiSearch 'Microsoft.Search/searchServices@2023-11-01' = {
  name: aiSearchName
  location: location
  tags: tags
  sku: {
    name: environment == 'prod' ? 'standard' : 'basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    replicaCount: environment == 'prod' ? 2 : 1
    partitionCount: 1
    publicNetworkAccess: isPrivate ? 'disabled' : 'enabled'
    disableLocalAuth: true
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http403'
      }
    }
  }
}

resource aiSearchDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${aiSearchName}'
  scope: aiSearch
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output cosmosDbId string = cosmosDb.id
output cosmosDbEndpoint string = cosmosDb.properties.documentEndpoint
output cosmosDbPrincipalId string = cosmosDb.identity.principalId
output aiSearchId string = aiSearch.id
output aiSearchName string = aiSearch.name
output aiSearchEndpoint string = 'https://${aiSearch.name}.search.windows.net'
output aiSearchPrincipalId string = aiSearch.identity.principalId
