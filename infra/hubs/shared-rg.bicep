// Shared Services Resource Group — APIM Gateway
//
// Resource-group-scoped template. Deploys APIM with one backend + API per
// Foundry tier, routing /foundry/{tier}/* to the corresponding Foundry endpoint.
// APIM uses its system-assigned managed identity (Azure AI User) to authenticate
// to all Foundry backends — no API keys.
//
// The resource group must be pre-created before this deployment.
//
// Usage:
//   az deployment group create \
//     --resource-group rg-agentops-shared-{hub} \
//     --template-file infra/hubs/shared-rg.bicep \
//     --parameters hub=amr location=eastus2 \
//                  foundryBackends='[{"tier":"mfs","endpoint":"https://..."}]' \
//                  entraIdTenantId=<tenant> publisherEmail=admin@... \
//                  costCenter=135355 environment=dev

targetScope = 'resourceGroup'

// ── Parameters ─────────────────────────────────────────────────────────────────

@description('Hub region: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hub string

@description('Primary Azure region')
param location string

@description('Array of Foundry backends: [{ tier: string, endpoint: string }]')
param foundryBackends array

@description('Entra ID tenant ID for JWT validation')
param entraIdTenantId string

@description('APIM publisher email')
param publisherEmail string

@description('APIM publisher organization name')
param publisherName string = 'KPMG AI OS Platform'

@description('APIM SKU: Developer for POC, StandardV2 or Premium for prod')
@allowed(['Developer', 'StandardV2', 'Premium'])
param apimSkuName string = 'Developer'

@description('APIM scale units')
param apimSkuCapacity int = 1

@description('Cost center code')
param costCenter string

@description('Deployment environment')
@allowed(['prod', 'uat', 'nonprod'])
param environment string = 'nonprod'

// ── Derived names ─────────────────────────────────────────────────────────────

var apimName        = 'apim-foundry-${hub}'
var lawName         = 'law-foundry-shared-${hub}'
var appInsightsName = 'ai-foundry-shared-${hub}'

var tags = {
  HubRegion  : hub
  ManagedBy  : 'foundry-platform'
  Environment: environment
  CostCenter : costCenter
}

// ── Monitoring ────────────────────────────────────────────────────────────────
module monitoring '../modules/monitoring/main.bicep' = {
  name: 'deploy-monitoring-shared-${hub}'
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

// ── APIM Service ──────────────────────────────────────────────────────────────
resource apimService 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: apimName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: apimSkuName
    capacity: apimSkuCapacity
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName : publisherName
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
    }
  }
}

// ── Named Values ──────────────────────────────────────────────────────────────
resource nvTenantId 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apimService
  name: 'entra-tenant-id'
  properties: {
    displayName: 'entra-tenant-id'
    value: entraIdTenantId
    secret: false
  }
}

resource nvFoundryAudience 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apimService
  name: 'foundry-audience'
  properties: {
    displayName: 'foundry-audience'
    value: 'https://cognitiveservices.azure.com/'
    secret: false
  }
}

// ── Global Policy ─────────────────────────────────────────────────────────────
resource globalPolicy 'Microsoft.ApiManagement/service/policies@2023-09-01-preview' = {
  parent: apimService
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''<policies>
  <inbound>
    <cors allow-credentials="false">
      <allowed-origins><origin>*</origin></allowed-origins>
      <allowed-methods><method>GET</method><method>POST</method><method>PUT</method><method>DELETE</method><method>OPTIONS</method></allowed-methods>
      <allowed-headers><header>*</header></allowed-headers>
    </cors>
  </inbound>
  <backend><forward-request /></backend>
  <outbound />
  <on-error />
</policies>'''
  }
}

// ── One backend + product + API per Foundry tier ──────────────────────────────
// Bicep for-loop creates one set of APIM resources per item in foundryBackends.
// Each tier gets:  backend → product → API (with MI auth policy)

@batchSize(1)
resource backends 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = [for b in foundryBackends: {
  parent: apimService
  name: 'foundry-${b.tier}-backend'
  properties: {
    description: 'Foundry ${b.tier} instance in ${hub}'
    url: b.endpoint
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}]

@batchSize(1)
resource products 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = [for b in foundryBackends: {
  parent: apimService
  name: '${b.tier}-foundry'
  properties: {
    displayName: '${b.tier} Foundry Platform (${hub})'
    description: 'Access to ${b.tier} Foundry instance — project provisioning and agent hosting'
    subscriptionRequired: true
    approvalRequired: true
    state: 'published'
  }
}]

@batchSize(1)
resource apis 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = [for b in foundryBackends: {
  parent: apimService
  name: 'foundry-${b.tier}-api'
  properties: {
    displayName: 'Foundry ${b.tier} API'
    description: 'Proxy to ${b.tier} Foundry instance in ${hub}. Supports all Foundry V2 endpoints.'
    subscriptionRequired: true
    path: 'foundry/${b.tier}'
    protocols: ['https']
    serviceUrl: b.endpoint
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
  }
  dependsOn: [backends]
}]

// ── Diagnostics ───────────────────────────────────────────────────────────────
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${apimName}'
  scope: apimService
  properties: {
    workspaceId: monitoring.outputs.workspaceId
    logs: [{ category: 'GatewayLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output apimId          string = apimService.id
output apimName        string = apimService.name
output apimGatewayUrl  string = apimService.properties.gatewayUrl
output apimPrincipalId string = apimService.identity.principalId
output lawId           string = monitoring.outputs.workspaceId
