// Hub VNet Module
//
// Creates the virtual network and subnets for a Foundry subscription (mfs or tax)
// or for the Shared Services subscription (apim).
//
// Foundry subscriptions (mfs | tax):
//   snet-foundry-pe       — private endpoints for Foundry account + platform services
//   snet-foundry-vnet-inj — Foundry agent VNet injection (delegated to AIServices)
//
// Shared Services subscription:
//   snet-foundry-pe       — private endpoints (Front Door origin PE, etc.)
//   snet-apim             — APIM Internal VNet injection (/27 minimum)
//
// For POC, Foundry runs with publicNetworkAccess = Enabled and the PE subnet is
// pre-provisioned for prod hardening. Set environment='prod' and pass subnetId to
// the foundry-instance module to switch to private-only mode.

@description('VNet name — e.g. vnet-foundry-mfs-amr')
param vnetName string

@description('Azure region')
param location string

@description('Hub region code: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Subscription tier this VNet belongs to: mfs | tax | shared')
@allowed(['mfs', 'gf-audit', 'gf-advisory', 'gf-tax', 'g9-us', 'g9-ca', 'g9-uk', 'g9-de', 'g9-fr', 'g9-nl', 'g9-au', 'g9-jp', 'g9-cn', 'shared'])
param subscriptionTier string

@description('VNet address space — e.g. 10.1.0.0/16')
param vnetAddressPrefix string

@description('Subnet for private endpoints — e.g. 10.1.1.0/24')
param peSubnetAddressPrefix string

@description('Subnet for Foundry agent VNet injection — e.g. 10.1.2.0/24. Required for mfs/tax tiers.')
param vnetInjectionSubnetAddressPrefix string = ''

@description('Subnet for APIM Internal VNet injection — /27 minimum, e.g. 10.1.21.0/27. Required for shared tier.')
param apimSubnetAddressPrefix string = ''

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

// ── VNet with PE subnet always present ───────────────────────────────────────
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'snet-foundry-pe'
        properties: {
          addressPrefix: peSubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ── VNet injection subnet — for mfs/tax: Foundry agent execution ──────────────
// Delegated to Microsoft.CognitiveServices/accounts so Foundry can assign
// private IPs to agent containers during runtime.
resource vnetInjSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = if (!empty(vnetInjectionSubnetAddressPrefix)) {
  parent: vnet
  name: 'snet-foundry-vnet-inj'
  properties: {
    addressPrefix: vnetInjectionSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    delegations: [
      {
        name: 'delegation-foundry-ai'
        properties: {
          serviceName: 'Microsoft.CognitiveServices/accounts'
        }
      }
    ]
  }
}

// ── APIM subnet — for shared: Internal APIM VNet injection ───────────────────
// Requires /27 or larger. No PE network policy needed here; APIM uses the
// subnet for egress to private backends.
resource apimSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = if (!empty(apimSubnetAddressPrefix)) {
  parent: vnet
  name: 'snet-apim'
  properties: {
    addressPrefix: apimSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
  }
  dependsOn: [vnetInjSubnet]
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output peSubnetId string = '${vnet.id}/subnets/snet-foundry-pe'
output vnetInjSubnetId string = !empty(vnetInjectionSubnetAddressPrefix) ? vnetInjSubnet.id : ''
output apimSubnetId string = !empty(apimSubnetAddressPrefix) ? apimSubnet.id : ''
