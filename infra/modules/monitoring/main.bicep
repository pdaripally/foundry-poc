// Regional Monitoring Stack
//
// Deploys Log Analytics workspace and Application Insights per regional hub.
// All Foundry instances and APIM in the same region send diagnostics here.

@description('Log Analytics workspace name — e.g. law-foundry-amr')
param workspaceName string

@description('Application Insights name — e.g. ai-foundry-amr')
param appInsightsName string

@description('Azure region')
param location string

@description('Hub region code for tagging')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Log retention in days — 90 prod, 30 dev')
param retentionDays int = 90

@description('Cost center code')
param costCenter string

@description('Environment')
@allowed(['prod', 'staging', 'dev'])
param environment string = 'prod'

var tags = {
  HubRegion: hubRegion
  ManagedBy: 'foundry-platform'
  Environment: environment
  CostCenter: costCenter
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: environment == 'prod' ? 10 : 2
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    RetentionInDays: retentionDays
  }
}

output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output appInsightsId string = appInsights.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
