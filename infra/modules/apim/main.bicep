// Azure API Management — Shared Services Subscription
//
// Routes AI traffic to Foundry instances deployed in MFS and Tax subscriptions.
// APIM uses its system-assigned managed identity to authenticate to Foundry endpoints
// (Azure AI User role assigned to APIM MI on each Foundry account by hub deployment).
//
// API surface exposed:
//   /foundry/mfs/{*path}  →  foundry-mfs-{region}.services.ai.azure.com
//   /foundry/tax/{*path}  →  foundry-tax-{region}.services.ai.azure.com
//
// Per-project routing (optional extension):
//   /foundry/mfs/projects/{project}/{*path}  →  project-scoped endpoint
//
// Policy chain:
//   1. Validate caller's Bearer token (Entra ID) or APIM subscription key
//   2. Add APIM MI bearer token for Foundry backend auth
//   3. Rate limit per subscription
//   4. Forward to correct Foundry backend

@description('APIM service name — e.g. apim-amr')
param apimName string

@description('Azure region for this APIM instance')
param location string

@description('Hub region: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Publisher email — required by APIM')
param publisherEmail string

@description('Publisher organization name')
param publisherName string

@description('APIM SKU: Developer for POC, StandardV2 or Premium for production')
@allowed(['Developer', 'StandardV2', 'Premium'])
param skuName string = 'Developer'

@description('APIM scale units — 1 for dev, 2+ for prod')
param skuCapacity int = 1

@description('Foundry MFS endpoint — e.g. https://foundry-mfs-amr.services.ai.azure.com/')
param foundryMfsEndpoint string

@description('Foundry Tax endpoint — e.g. https://foundry-tax-amr.services.ai.azure.com/')
param foundryTaxEndpoint string

@description('Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('VNet subnet ID for APIM VNet injection — leave empty for public mode')
param vnetSubnetId string = ''

@description('Entra ID tenant ID for JWT validation')
param entraIdTenantId string

@description('Expected audience for Foundry Bearer tokens')
param foundryAudience string = 'https://cognitiveservices.azure.com/'

@description('Cost center code')
param costCenter string

@description('Environment: prod | staging | dev')
@allowed(['prod', 'staging', 'dev'])
param environment string = 'prod'

var tags = {
  ApimInstance: apimName
  HubRegion: hubRegion
  ManagedBy: 'foundry-platform'
  Environment: environment
  CostCenter: costCenter
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
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: !empty(vnetSubnetId) ? 'Internal' : 'None'
    virtualNetworkConfiguration: !empty(vnetSubnetId) ? {
      subnetResourceId: vnetSubnetId
    } : null
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
    }
  }
}

// ── Named Values (configuration store) ────────────────────────────────────────
resource nvFoundryMfsEndpoint 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apimService
  name: 'foundry-mfs-endpoint'
  properties: {
    displayName: 'foundry-mfs-endpoint'
    value: foundryMfsEndpoint
    secret: false
  }
}

resource nvFoundryTaxEndpoint 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apimService
  name: 'foundry-tax-endpoint'
  properties: {
    displayName: 'foundry-tax-endpoint'
    value: foundryTaxEndpoint
    secret: false
  }
}

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
    value: foundryAudience
    secret: false
  }
}

// ── Backend: Foundry MFS ──────────────────────────────────────────────────────
resource backendMfs 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apimService
  name: 'foundry-mfs-backend'
  properties: {
    description: 'Foundry MFS instance in ${hubRegion}'
    url: foundryMfsEndpoint
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// ── Backend: Foundry Tax ──────────────────────────────────────────────────────
resource backendTax 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apimService
  name: 'foundry-tax-backend'
  properties: {
    description: 'Foundry Tax instance in ${hubRegion}'
    url: foundryTaxEndpoint
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// ── APIM Products ─────────────────────────────────────────────────────────────
resource mfsProduct 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apimService
  name: 'mfs-foundry'
  properties: {
    displayName: 'MFS Foundry Platform (${hubRegion})'
    description: 'Access to MFS Shared Foundry instance — project vending and agent hosting'
    subscriptionRequired: true
    approvalRequired: true
    state: 'published'
  }
}

resource taxProduct 'Microsoft.ApiManagement/service/products@2023-09-01-preview' = {
  parent: apimService
  name: 'tax-foundry'
  properties: {
    displayName: 'Global Function Tax Foundry (${hubRegion})'
    description: 'Access to Global Function Tax Foundry instance — project vending and agent hosting'
    subscriptionRequired: true
    approvalRequired: true
    state: 'published'
  }
}

// ── Global inbound policy — JWT validation + MI token injection ───────────────
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

// ── MFS API ───────────────────────────────────────────────────────────────────
resource mfsApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apimService
  name: 'foundry-mfs-api'
  properties: {
    displayName: 'Foundry MFS API'
    description: 'Proxy to MFS Foundry instance. Supports all Foundry V2 endpoints including /openai/v1/, /api/projects/, and /agents/.'
    subscriptionRequired: true
    path: 'foundry/mfs'
    protocols: ['https']
    serviceUrl: foundryMfsEndpoint
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
  }
}

resource mfsApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: mfsApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''<policies>
  <inbound>
    <base />
    <!-- Acquire APIM Managed Identity token for Foundry backend -->
    <authentication-managed-identity resource="{{foundry-audience}}" output-token-variable-name="msi-access-token" ignore-error="false" />
    <set-header name="Authorization" exists-action="override">
      <value>@("Bearer " + (string)context.Variables["msi-access-token"])</value>
    </set-header>
    <!-- Rate limiting per subscription key: 1000 calls / 60s -->
    <rate-limit-by-key calls="1000" renewal-period="60" counter-key="@(context.Subscription.Id)" />
    <!-- Token quota per day -->
    <quota-by-key calls="100000" renewal-period="86400" counter-key="@(context.Subscription.Id)" />
    <set-backend-service backend-id="foundry-mfs-backend" />
  </inbound>
  <backend><forward-request timeout="120" /></backend>
  <outbound>
    <base />
    <!-- Remove upstream auth headers from response -->
    <set-header name="x-ms-client-request-id" exists-action="delete" />
  </outbound>
  <on-error><base /></on-error>
</policies>'''
  }
}

// ── Tax API ───────────────────────────────────────────────────────────────────
resource taxApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apimService
  name: 'foundry-tax-api'
  properties: {
    displayName: 'Foundry Tax API'
    description: 'Proxy to Global Function Tax Foundry instance. Supports all Foundry V2 endpoints.'
    subscriptionRequired: true
    path: 'foundry/tax'
    protocols: ['https']
    serviceUrl: foundryTaxEndpoint
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
  }
}

resource taxApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: taxApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''<policies>
  <inbound>
    <base />
    <authentication-managed-identity resource="{{foundry-audience}}" output-token-variable-name="msi-access-token" ignore-error="false" />
    <set-header name="Authorization" exists-action="override">
      <value>@("Bearer " + (string)context.Variables["msi-access-token"])</value>
    </set-header>
    <rate-limit-by-key calls="1000" renewal-period="60" counter-key="@(context.Subscription.Id)" />
    <quota-by-key calls="100000" renewal-period="86400" counter-key="@(context.Subscription.Id)" />
    <set-backend-service backend-id="foundry-tax-backend" />
  </inbound>
  <backend><forward-request timeout="120" /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>'''
  }
}

// ── Link APIs to products ─────────────────────────────────────────────────────
resource mfsProductApi 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: mfsProduct
  name: mfsApi.name
}

resource taxProductApi 'Microsoft.ApiManagement/service/products/apis@2023-09-01-preview' = {
  parent: taxProduct
  name: taxApi.name
}

// ── Diagnostics ───────────────────────────────────────────────────────────────
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${apimName}'
  scope: apimService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'GatewayLogs'; enabled: true }
      { category: 'WebSocketConnectionLogs'; enabled: false }
    ]
    metrics: [
      { category: 'AllMetrics'; enabled: true }
    ]
  }
}

output apimId string = apimService.id
output apimName string = apimService.name
output apimGatewayUrl string = apimService.properties.gatewayUrl
output apimPrincipalId string = apimService.identity.principalId
output mfsApiPath string = mfsApi.properties.path
output taxApiPath string = taxApi.properties.path
