package foundry.quota

# Foundry Quota Governance Policy
#
# Enforces scalability thresholds per the architecture:
#   - Max ~250 projects per Foundry instance before a new instance is needed
#   - Confidential/Restricted data cannot be deployed to nonprod environment
#   - GF Tax tier cannot host public data classification projects
#
# Environments: nonprod (dev & QA), uat, prod

import future.keywords.if
import future.keywords.in

default allow = false

allow if {
    not exceeds_project_quota
    valid_data_classification_for_env
    valid_data_classification_for_tier
}

max_projects_per_instance := 240

exceeds_project_quota if {
    input.current_project_count >= max_projects_per_instance
}

exceeds_project_quota := false if {
    not input.current_project_count
}

# Confidential or Restricted data cannot go to nonprod
valid_data_classification_for_env if {
    input.environment == "nonprod"
    input.data_classification in {"public", "internal"}
}

valid_data_classification_for_env if {
    input.environment in {"uat", "prod"}
}

# GF Tax tier should not host public data
valid_data_classification_for_tier if {
    input.subscription_tier == "gf-tax"
    input.data_classification in {"internal", "confidential", "restricted"}
}

valid_data_classification_for_tier if {
    input.subscription_tier != "gf-tax"
}

violations contains msg if {
    exceeds_project_quota
    msg := sprintf(
        "Foundry instance 'foundry-%v-%v' has reached the project capacity threshold (%v/%v).",
        [input.subscription_tier, input.hub, input.current_project_count, max_projects_per_instance]
    )
}

violations contains msg if {
    not valid_data_classification_for_env
    msg := sprintf(
        "Data classification '%v' is not allowed in '%v' environment. nonprod only supports public and internal.",
        [input.data_classification, input.environment]
    )
}

violations contains msg if {
    not valid_data_classification_for_tier
    msg := sprintf(
        "Data classification '%v' is not allowed in the 'gf-tax' tier. Must be internal, confidential, or restricted.",
        [input.data_classification]
    )
}
