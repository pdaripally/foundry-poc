// Microsoft Foundry V2 — Project Provisioning Module
//
// Creates a Foundry project (child of an existing Foundry account) with:
//   - Full workload isolation via custom RBAC roles
//   - Project Admin role: manage project, add/remove users, NO model deployment
//   - Project User role: inference + agents + evaluations, NO model deployment
//   - Diagnostics to regional Log Analytics workspace
//
// SCOPE: Deploy to the resource group that contains the parent Foundry account.
//
// RBAC design:
//   Project Admin (custom) @ project scope  — manage project + inference
//   Project User  (custom) @ project scope  — inference + agents only
//   Both roles have notActions: deployments/write — enforces model deployment governance
//
// The parent Foundry account's model deployments are shared read-only across all
// projects. Adding new models requires a separate model-approval workflow targeting
// the account scope, which requires platform admin permissions.

@description('Project name — convention: {subscriptionTier}-{hubRegion}-{workload}-{env}')
param projectName string

@description('Human-readable display name shown in Foundry portal')
param displayName string

@description('Workload description for tagging and documentation')
param workloadDescription string

@description('Name of the parent Foundry account in this resource group')
param foundryAccountName string

@description('Hub region: amr | emea | apac')
@allowed(['amr', 'emea', 'apac'])
param hubRegion string

@description('Subscription tier: mfs | tax')
@allowed(['mfs', 'tax'])
param subscriptionTier string

@description('Target environment')
@allowed(['nonprod', 'uat', 'prod'])
param environment string

@description('Data classification')
@allowed(['public', 'internal', 'confidential', 'restricted'])
param dataClassification string

@description('Cost center code for chargeback')
param costCenter string

@description('AAD object ID of the Project Admin user or group')
param projectAdminObjectId string

@description('Principal type for projectAdminObjectId: User | Group | ServicePrincipal')
@allowed(['User', 'Group', 'ServicePrincipal'])
param projectAdminPrincipalType string = 'Group'

@description('AAD object ID of the Project Users group — leave empty to skip')
param projectUserGroupObjectId string = ''

@description('Log Analytics workspace resource ID for diagnostics')
param logAnalyticsWorkspaceId string

@description('Resource ID of the Foundry Project Admin custom role definition')
param foundryProjectAdminRoleId string

@description('Resource ID of the Foundry Project User custom role definition')
param foundryProjectUserRoleId string

var tags = {
  ProjectName: projectName
  HubRegion: hubRegion
  SubscriptionTier: subscriptionTier
  Environment: environment
  DataClassification: dataClassification
  Workload: workloadDescription
  CostCenter: costCenter
  ManagedBy: 'foundry-platform'
}

// ── Parent Foundry account (existing) ────────────────────────────────────────
resource foundryAccount 'Microsoft.CognitiveServices/accounts@2026-03-01' existing = {
  name: foundryAccountName
}

// ── Foundry Project (Foundry V2 child resource) ───────────────────────────────
resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2026-03-01' = {
  parent: foundryAccount
  name: projectName
  location: resourceGroup().location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: workloadDescription
    displayName: displayName
  }
}

// ── Project diagnostics ───────────────────────────────────────────────────────
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${projectName}'
  scope: foundryProject
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// ── RBAC: Project Admin at project scope ──────────────────────────────────────
// Custom role: can manage project settings + inference, CANNOT deploy models
resource projectAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryProject.id, projectAdminObjectId, foundryProjectAdminRoleId)
  scope: foundryProject
  properties: {
    roleDefinitionId: foundryProjectAdminRoleId
    principalId: projectAdminObjectId
    principalType: projectAdminPrincipalType
  }
}

// ── RBAC: Project User group at project scope (optional) ──────────────────────
// Custom role: inference + agents + evaluations only, CANNOT deploy models
resource projectUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(projectUserGroupObjectId)) {
  name: guid(foundryProject.id, projectUserGroupObjectId, foundryProjectUserRoleId)
  scope: foundryProject
  properties: {
    roleDefinitionId: foundryProjectUserRoleId
    principalId: projectUserGroupObjectId
    principalType: 'Group'
  }
}

// ── RBAC: Project managed identity needs Azure AI User on parent account ──────
// The project MI needs to call models on the parent account during agent execution.
var azureAIUserRoleId = 'bef2f8c4-8176-4b1f-bcfe-42e15a4d4a5d'
resource projectMiAccountRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryAccount.id, foundryProject.identity.principalId, azureAIUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureAIUserRoleId)
    principalId: foundryProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output projectId string = foundryProject.id
output projectName string = foundryProject.name
output projectPrincipalId string = foundryProject.identity.principalId
output projectEndpoint string = '${foundryAccount.properties.endpoint}api/projects/${foundryProject.name}'
output foundryAccountEndpoint string = foundryAccount.properties.endpoint
