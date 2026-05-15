package foundry.quota

# Foundry Quota Governance Policy
#
# Enforces scalability thresholds per the architecture:
#   - Max ~250 projects per Foundry instance before a new instance is needed
#   - Confidential/Restricted data cannot be deployed to dev environment
#   - Tax subscription cannot host public data classification projects
#
# In the GitHub workflow, project count is injected into input.current_project_count
# by querying Azure: az cognitiveservices account project list ...
# If not provided, quota check passes (conservative default for POC).

import future.keywords.if
import future.keywords.in

default allow = false

allow if {
    not exceeds_project_quota
    valid_data_classification_for_env
    valid_data_classification_for_tier
}

# Hard limit: Foundry supports ~250 projects per account
max_projects_per_instance := 240  # Leave buffer before platform limit

exceeds_project_quota if {
    input.current_project_count >= max_projects_per_instance
}

# Default: if current_project_count not provided, assume quota is fine
exceeds_project_quota := false if {
    not input.current_project_count
}

# Confidential or Restricted data cannot go to dev environment
valid_data_classification_for_env if {
    input.environment == "dev"
    input.data_classification in {"public", "internal"}
}

valid_data_classification_for_env if {
    input.environment in {"staging", "prod"}
}

# Tax subscription should not host public data (tax data is inherently sensitive)
valid_data_classification_for_tier if {
    input.subscription_tier == "tax"
    input.data_classification in {"internal", "confidential", "restricted"}
}

valid_data_classification_for_tier if {
    input.subscription_tier == "mfs"
}

# Violations — surfaced as a set for human-readable error messages
violations contains msg if {
    exceeds_project_quota
    msg := sprintf(
        "Foundry instance 'foundry-%v-%v' has reached the project capacity threshold (%v/%v). A new Foundry instance must be provisioned before vending additional projects.",
        [input.subscription_tier, input.hub, input.current_project_count, max_projects_per_instance]
    )
}

violations contains msg if {
    not valid_data_classification_for_env
    msg := sprintf(
        "Data classification '%v' is not allowed in '%v' environment. Dev environment only supports public and internal classifications.",
        [input.data_classification, input.environment]
    )
}

violations contains msg if {
    not valid_data_classification_for_tier
    msg := sprintf(
        "Data classification '%v' is not allowed in the 'tax' subscription tier. Tax workloads must use internal, confidential, or restricted classification.",
        [input.data_classification]
    )
}
