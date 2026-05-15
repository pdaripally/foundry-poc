package foundry.naming

# Foundry Project Naming Convention Policy
#
# Enforces the convention: {hub}-{tier}-{env}-{workload}
# where:
#   hub      ∈ {amr, emea, apac}
#   tier     ∈ {mfs, gf-audit, gf-advisory, gf-tax, g9-us, g9-ca, g9-uk, g9-de, g9-fr, g9-nl, g9-au, g9-jp, g9-cn}
#   env      ∈ {nonprod, uat, prod}
#   workload = lowercase alphanumeric + hyphens, 2-20 chars, starts with letter/digit

import future.keywords.if
import future.keywords.in

default allow = false

allow if {
    valid_hub
    valid_tier
    valid_env
    valid_workload
    valid_project_name_format
}

valid_hub if {
    input.hub in {"amr", "emea", "apac"}
}

valid_tier if {
    input.subscription_tier in {
        "mfs", "gf-audit", "gf-advisory", "gf-tax",
        "g9-us", "g9-ca", "g9-uk", "g9-de", "g9-fr",
        "g9-nl", "g9-au", "g9-jp", "g9-cn"
    }
}

valid_env if {
    input.environment in {"nonprod", "uat", "prod"}
}

valid_workload if {
    regex.match(`^[a-z0-9][a-z0-9-]{1,19}$`, input.workload_name)
}

valid_project_name_format if {
    expected := sprintf("%v-%v-%v-%v", [
        input.hub,
        input.subscription_tier,
        input.environment,
        input.workload_name,
    ])
    input.project_name == expected
}

valid_foundry_account if {
    expected := sprintf("foundry-%v-%v", [input.subscription_tier, input.hub])
    input.foundry_account == expected
}

violations contains msg if {
    not valid_hub
    msg := sprintf("hub '%v' is not valid. Must be one of: amr, emea, apac", [input.hub])
}

violations contains msg if {
    not valid_tier
    msg := sprintf("subscription_tier '%v' is not valid.", [input.subscription_tier])
}

violations contains msg if {
    not valid_env
    msg := sprintf("environment '%v' is not valid. Must be one of: nonprod, uat, prod", [input.environment])
}

violations contains msg if {
    not valid_workload
    msg := sprintf("workload_name '%v' is invalid. Must match ^[a-z0-9][a-z0-9-]{1,19}$", [input.workload_name])
}

violations contains msg if {
    not valid_project_name_format
    expected := sprintf("%v-%v-%v-%v", [
        input.hub,
        input.subscription_tier,
        input.environment,
        input.workload_name,
    ])
    msg := sprintf("project_name '%v' does not follow convention. Expected: '%v'", [input.project_name, expected])
}
