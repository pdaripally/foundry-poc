// Approved Models Policy Assignment
//
// Assigns a pre-created policy definition at resource group scope.
// The policy denies any Microsoft.CognitiveServices/accounts/deployments resource
// whose model.name is not in the hub-approved list.
//
// This is the "suspenders" layer of model governance:
//   Belt      — custom RBAC notActions on Project User/Admin roles
//   Suspenders — this Azure Policy deny effect at the Foundry RG scope
//
// Deploy this module scoped to the Foundry resource group (rg-foundry-mfs-{region}
// or rg-foundry-tax-{region}). The policy definition is created at subscription
// scope in the hub subscription file.

@description('Resource ID of the approved-models policy definition (created at subscription scope)')
param policyDefinitionId string

@description('Human-readable display name for the assignment')
param assignmentDisplayName string = 'Foundry — approved model deployments only'

resource assignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'assign-foundry-approved-models'
  properties: {
    policyDefinitionId: policyDefinitionId
    displayName: assignmentDisplayName
    description: 'Denies Foundry model deployments where model.name is not in the hub-approved list. Managed by foundry-platform.'
    enforcementMode: 'Default'
    nonComplianceMessages: [
      {
        message: 'Model deployment denied. Only hub-approved models may be deployed to this Foundry instance. Submit a model-approval-request GitHub issue to add a new model.'
      }
    ]
  }
}

output assignmentId string = assignment.id
output assignmentName string = assignment.name
