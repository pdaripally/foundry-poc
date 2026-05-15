// Custom RBAC Role Definitions for Foundry Project Isolation
//
// Deployed at subscription scope. Two roles:
//
//   Foundry Project User  — inference + agents + evaluations within a project.
//                           Explicitly CANNOT provision/delete model deployments.
//
//   Foundry Project Admin — all Project User permissions plus project management
//                           (settings, connections, member access). Still CANNOT
//                           provision/delete model deployments.
//
// Model deployment governance is enforced via:
//   1. notActions on both custom roles (belt)
//   2. Azure Policy deny effect in infra/policy/deny-model-provisioning.json (suspenders)
//
// Assign roles at Foundry PROJECT scope, not at account scope.
// The project managed identity gets Azure AI User at account scope separately
// so it can reach model deployments during agent execution.

targetScope = 'subscription'

param subscriptionId string = subscription().subscriptionId

// ── Foundry Project User ──────────────────────────────────────────────────────
resource foundryProjectUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('FoundryProjectUser', subscriptionId)
  properties: {
    roleName: 'Foundry Project User'
    description: 'Run AI workloads within a Foundry project — inference, agents, and evaluations. Cannot provision or delete model deployments.'
    type: 'CustomRole'
    assignableScopes: [
      '/subscriptions/${subscriptionId}'
    ]
    permissions: [
      {
        actions: [
          'Microsoft.CognitiveServices/*/read'
          'Microsoft.Resources/*/read'
          'Microsoft.Authorization/*/read'
          'Microsoft.Insights/*/read'
        ]
        notActions: [
          // Model deployment governance — project users can never deploy new models
          'Microsoft.CognitiveServices/accounts/deployments/write'
          'Microsoft.CognitiveServices/accounts/deployments/delete'
          // Prevent account-level mutations
          'Microsoft.CognitiveServices/accounts/write'
          'Microsoft.CognitiveServices/accounts/delete'
          // Prevent deleting other projects
          'Microsoft.CognitiveServices/accounts/projects/delete'
        ]
        dataActions: [
          // Agents — create, run, manage tools within project scope
          'Microsoft.CognitiveServices/accounts/AIServices/agents/*'
          // Evaluations — run quality assessments within project scope
          'Microsoft.CognitiveServices/accounts/AIServices/evaluations/*'
          // Model inference via project endpoint
          'Microsoft.CognitiveServices/accounts/AIServices/inference/*'
          // OpenAI-compatible inference endpoints
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/chat/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/embeddings/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/extensions/chat/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/images/generations/action'
          // File operations within project
          'Microsoft.CognitiveServices/accounts/AIServices/files/read'
          'Microsoft.CognitiveServices/accounts/AIServices/files/write'
          'Microsoft.CognitiveServices/accounts/AIServices/files/delete'
        ]
        notDataActions: []
      }
    ]
  }
}

// ── Foundry Project Admin ─────────────────────────────────────────────────────
resource foundryProjectAdminRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('FoundryProjectAdmin', subscriptionId)
  properties: {
    roleName: 'Foundry Project Admin'
    description: 'Manage a Foundry project — settings, connections, and user access. Includes all Project User permissions. Cannot provision or delete model deployments.'
    type: 'CustomRole'
    assignableScopes: [
      '/subscriptions/${subscriptionId}'
    ]
    permissions: [
      {
        actions: [
          'Microsoft.CognitiveServices/*/read'
          // Project lifecycle management
          'Microsoft.CognitiveServices/accounts/projects/write'
          // Connection management within project
          'Microsoft.CognitiveServices/accounts/projects/connections/read'
          'Microsoft.CognitiveServices/accounts/projects/connections/write'
          'Microsoft.CognitiveServices/accounts/projects/connections/delete'
          // Role assignments — allows Project Admin to assign Foundry Project User to others
          'Microsoft.Authorization/roleAssignments/write'
          'Microsoft.Authorization/roleAssignments/delete'
          'Microsoft.Authorization/*/read'
          'Microsoft.Resources/deployments/*'
          'Microsoft.Resources/*/read'
          'Microsoft.Insights/*/read'
        ]
        notActions: [
          // Model deployment governance — project admins can never deploy new models
          'Microsoft.CognitiveServices/accounts/deployments/write'
          'Microsoft.CognitiveServices/accounts/deployments/delete'
          // Prevent account-level mutations
          'Microsoft.CognitiveServices/accounts/write'
          'Microsoft.CognitiveServices/accounts/delete'
        ]
        dataActions: [
          // All inference + agent + evaluation data actions (superset of Project User)
          'Microsoft.CognitiveServices/accounts/AIServices/agents/*'
          'Microsoft.CognitiveServices/accounts/AIServices/evaluations/*'
          'Microsoft.CognitiveServices/accounts/AIServices/inference/*'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/chat/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/embeddings/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/extensions/chat/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/images/generations/action'
          'Microsoft.CognitiveServices/accounts/AIServices/files/read'
          'Microsoft.CognitiveServices/accounts/AIServices/files/write'
          'Microsoft.CognitiveServices/accounts/AIServices/files/delete'
          // Admin extras — trace and monitoring data
          'Microsoft.CognitiveServices/accounts/AIServices/traces/*'
        ]
        notDataActions: []
      }
    ]
  }
}

output projectUserRoleId string = foundryProjectUserRole.id
output projectUserRoleDefinitionName string = foundryProjectUserRole.name
output projectAdminRoleId string = foundryProjectAdminRole.id
output projectAdminRoleDefinitionName string = foundryProjectAdminRole.name
