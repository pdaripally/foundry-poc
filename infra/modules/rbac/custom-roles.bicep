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
// Data actions verified against az provider operation show --namespace Microsoft.CognitiveServices

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
          'Microsoft.CognitiveServices/accounts/deployments/write'
          'Microsoft.CognitiveServices/accounts/deployments/delete'
          'Microsoft.CognitiveServices/accounts/write'
          'Microsoft.CognitiveServices/accounts/delete'
          'Microsoft.CognitiveServices/accounts/projects/delete'
        ]
        dataActions: [
          // Agents — create, run, manage within project scope
          'Microsoft.CognitiveServices/accounts/AIServices/agents/read'
          'Microsoft.CognitiveServices/accounts/AIServices/agents/write'
          'Microsoft.CognitiveServices/accounts/AIServices/agents/delete'
          // Evaluations — run quality assessments within project scope
          'Microsoft.CognitiveServices/accounts/AIServices/evaluations/read'
          'Microsoft.CognitiveServices/accounts/AIServices/evaluations/write'
          'Microsoft.CognitiveServices/accounts/AIServices/evaluations/delete'
          // Inference via AIServices unified endpoint
          'Microsoft.CognitiveServices/accounts/AIServices/providers/action'
          'Microsoft.CognitiveServices/accounts/AIServices/applications/invoke/action'
          // Responses API (stateful inference)
          'Microsoft.CognitiveServices/accounts/AIServices/responses/read'
          'Microsoft.CognitiveServices/accounts/AIServices/responses/write'
          'Microsoft.CognitiveServices/accounts/AIServices/responses/delete'
          // OpenAI-compatible inference endpoints
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/chat/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/embeddings/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/extensions/chat/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/audio/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/realtime/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/images/generations/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/responses/read'
          'Microsoft.CognitiveServices/accounts/OpenAI/responses/write'
          'Microsoft.CognitiveServices/accounts/OpenAI/responses/delete'
          // Files for assistant/agent tool use
          'Microsoft.CognitiveServices/accounts/OpenAI/files/read'
          'Microsoft.CognitiveServices/accounts/OpenAI/files/write'
          'Microsoft.CognitiveServices/accounts/OpenAI/files/delete'
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
          'Microsoft.CognitiveServices/accounts/projects/write'
          'Microsoft.CognitiveServices/accounts/projects/connections/read'
          'Microsoft.CognitiveServices/accounts/projects/connections/write'
          'Microsoft.CognitiveServices/accounts/projects/connections/delete'
          'Microsoft.Authorization/roleAssignments/write'
          'Microsoft.Authorization/roleAssignments/delete'
          'Microsoft.Authorization/*/read'
          'Microsoft.Resources/deployments/*'
          'Microsoft.Resources/*/read'
          'Microsoft.Insights/*/read'
        ]
        notActions: [
          'Microsoft.CognitiveServices/accounts/deployments/write'
          'Microsoft.CognitiveServices/accounts/deployments/delete'
          'Microsoft.CognitiveServices/accounts/write'
          'Microsoft.CognitiveServices/accounts/delete'
        ]
        dataActions: [
          // All Project User data actions
          'Microsoft.CognitiveServices/accounts/AIServices/agents/read'
          'Microsoft.CognitiveServices/accounts/AIServices/agents/write'
          'Microsoft.CognitiveServices/accounts/AIServices/agents/delete'
          'Microsoft.CognitiveServices/accounts/AIServices/evaluations/read'
          'Microsoft.CognitiveServices/accounts/AIServices/evaluations/write'
          'Microsoft.CognitiveServices/accounts/AIServices/evaluations/delete'
          'Microsoft.CognitiveServices/accounts/AIServices/providers/action'
          'Microsoft.CognitiveServices/accounts/AIServices/applications/invoke/action'
          'Microsoft.CognitiveServices/accounts/AIServices/responses/read'
          'Microsoft.CognitiveServices/accounts/AIServices/responses/write'
          'Microsoft.CognitiveServices/accounts/AIServices/responses/delete'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/chat/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/embeddings/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/extensions/chat/completions/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/audio/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/deployments/realtime/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/images/generations/action'
          'Microsoft.CognitiveServices/accounts/OpenAI/responses/read'
          'Microsoft.CognitiveServices/accounts/OpenAI/responses/write'
          'Microsoft.CognitiveServices/accounts/OpenAI/responses/delete'
          'Microsoft.CognitiveServices/accounts/OpenAI/files/read'
          'Microsoft.CognitiveServices/accounts/OpenAI/files/write'
          'Microsoft.CognitiveServices/accounts/OpenAI/files/delete'
          // Admin extras — assets, fine-tuning, connections, traces
          'Microsoft.CognitiveServices/accounts/AIServices/assets/read'
          'Microsoft.CognitiveServices/accounts/AIServices/assets/write'
          'Microsoft.CognitiveServices/accounts/AIServices/assets/delete'
          'Microsoft.CognitiveServices/accounts/AIServices/fine_tuning/read'
          'Microsoft.CognitiveServices/accounts/AIServices/fine_tuning/write'
          'Microsoft.CognitiveServices/accounts/AIServices/fine_tuning/delete'
          'Microsoft.CognitiveServices/accounts/AIServices/connections/read'
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
