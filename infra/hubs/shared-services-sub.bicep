// Shared Services Subscription — Regional Hub Deployment
//
// Subscription-scoped deployment. Creates the Shared Services resources
// for a regional hub: APIM Internal gateway that routes AI traffic to
// Foundry instances in MFS and Tax subscriptions.
//
// APIM uses its system-assigned managed identity (Azure AI User role granted
// on each Foundry account by the deploy-hub workflow after Foundry endpoints
// are known) to authenticate to the Foundry backends — no API keys.
//
// VNet peering:
//   For prod: peer shared-vnet → mfs-vnet and shared-vnet → tax-vnet to
//   allow APIM to reach Foundry private endpoints. For POC, APIM reaches
//   Foundry via public endpoint (foundryMfsEndpoint / foundryTaxEndpoint
//   are public HTTPS URLs).
//
// Usage:
//   az deployment sub create \
//     --location <location> \
//     --template-file infra/hubs/shared-services-sub.bicep \
//     --parameters @infra/hubs/amr/shared-services-sub.params.json \
//     --parameters foundryMfsEndpoint=<value> foundryTaxEndpoint=<value>

targetScope = 'subscription'

// ── Parameters ─────────────────────────────────────────────────────────────────

@description('Hub region: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Primary Azure region for resource deployment')
param location string

@description('VNet address space for Shared Services — e.g. 10.1.32.0/20')
param vnetAddressPrefix string

@description('Private endpoint subnet address prefix — e.g. 10.1.33.0/24')
param peSubnetAddressPrefix string

@description('APIM Internal VNet injection subnet address prefix — /27 minimum, e.g. 10.1.33.128/27')
param apimSubnetAddressPrefix string

@description('Foundry MFS instance HTTPS endpoint — e.g. https://foundry-mfs-amr.services.ai.azure.com/')
param foundryMfsEndpoint string

@description('Foundry Tax instance HTTPS endpoint — e.g. https://foundry-tax-amr.services.ai.azure.com/')
param foundryTaxEndpoint string

@description('Entra ID tenant ID for JWT validation in APIM policy')
param entraIdTenantId string

@description('APIM publisher email — required by APIM service')
param publisherEmail string

@description('APIM publisher organization name')
param publisherName string

@description('APIM SKU: Developer for POC, StandardV2 or Premium for prod')
@allowed(['Developer', 'StandardV2', 'Premium'])
param apimSkuName string = 'Developer'

@description('APIM scale units')
param apimSkuCapacity int = 1

@description('Cost center code')
param costCenter string

@description('Deployment environment')
@allowed(['prod', 'staging', 'dev'])
param environment string = 'prod'

// ── Derived names ─────────────────────────────────────────────────────────────

var rgName = 'rg-foundry-shared-${hubRegion}'
var apimName = 'apim-foundry-${hubRegion}'
var lawName = 'law-foundry-shared-${hubRegion}'
var appInsightsName = 'ai-foundry-shared-${hubRegion}'
var vnetName = 'vnet-foundry-shared-${hubRegion}'

var tags = {
  HubRegion: hubRegion
  SubscriptionTier: 'shared'
  ManagedBy: 'foundry-platform'
  Environment: environment
  CostCenter: costCenter
}

// ── Resource Group ────────────────────────────────────────────────────────────
resource sharedRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgName
  location: location
  tags: tags
}

// ── Monitoring ────────────────────────────────────────────────────────────────
module monitoring '../modules/monitoring/main.bicep' = {
  name: 'deploy-monitoring-shared-${hubRegion}'
  scope: sharedRg
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
  name: 'deploy-networking-shared-${hubRegion}'
  scope: sharedRg
  params: {
    vnetName: vnetName
    location: location
    hubRegion: hubRegion
    subscriptionTier: 'shared'
    vnetAddressPrefix: vnetAddressPrefix
    peSubnetAddressPrefix: peSubnetAddressPrefix
    apimSubnetAddressPrefix: apimSubnetAddressPrefix
    costCenter: costCenter
    environment: environment
  }
}

// ── APIM Internal Gateway ─────────────────────────────────────────────────────
// Routes /foundry/mfs/* → MFS Foundry instance
// Routes /foundry/tax/* → Tax Foundry instance
// Authenticates to Foundry backends using APIM managed identity (Azure AI User role)
module apim '../modules/apim/main.bicep' = {
  name: 'deploy-apim-${hubRegion}'
  scope: sharedRg
  params: {
    apimName: apimName
    location: location
    hubRegion: hubRegion
    publisherEmail: publisherEmail
    publisherName: publisherName
    skuName: apimSkuName
    skuCapacity: apimSkuCapacity
    foundryMfsEndpoint: foundryMfsEndpoint
    foundryTaxEndpoint: foundryTaxEndpoint
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    // POC: no VNet injection. For prod: networking.outputs.apimSubnetId
    vnetSubnetId: environment == 'prod' ? networking.outputs.apimSubnetId : ''
    entraIdTenantId: entraIdTenantId
    costCenter: costCenter
    environment: environment
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────
output rgName string = rgName
output apimId string = apim.outputs.apimId
output apimName string = apim.outputs.apimName
output apimGatewayUrl string = apim.outputs.apimGatewayUrl
output apimPrincipalId string = apim.outputs.apimPrincipalId
output lawId string = monitoring.outputs.workspaceId
output vnetId string = networking.outputs.vnetId
