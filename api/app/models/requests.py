from pydantic import BaseModel, Field
from typing import Literal, Optional


class DeployHubRequest(BaseModel):
    hub: Literal["amr", "emea", "apac"] = Field(..., description="Regional hub to deploy")
    environment: Literal["nonprod", "uat", "prod"] = Field("nonprod", description="Target environment")
    dry_run: bool = Field(False, description="What-if only — no resources are created")


class ProvisionProjectRequest(BaseModel):
    hub: Literal["amr", "emea", "apac"] = Field(..., description="Hub region")
    subscription_tier: Literal[
        "mfs", "gf-audit", "gf-advisory", "gf-tax",
        "g9-us", "g9-ca", "g9-uk", "g9-de", "g9-fr",
        "g9-nl", "g9-au", "g9-jp", "g9-cn"
    ] = Field(..., description="Target Foundry resource group tier")
    workload_name: str = Field(..., description="Workload name — lowercase alphanumeric + hyphens, max 20 chars")
    environment: Literal["nonprod", "uat", "prod"] = Field("nonprod", description="Target environment")
    data_classification: Literal["public", "internal", "confidential", "restricted"] = Field(
        "internal", description="Data classification level"
    )
    cost_center: str = Field(..., description="Cost center code for billing chargeback")
    project_admin_group_oid: str = Field(..., description="Entra ID object ID of the Project Admin group")
    project_user_group_oid: Optional[str] = Field("", description="Entra ID object ID of the Project Users group")


class DeprovisionProjectRequest(BaseModel):
    hub: Literal["amr", "emea", "apac"] = Field(..., description="Hub region")
    subscription_tier: Literal[
        "mfs", "gf-audit", "gf-advisory", "gf-tax",
        "g9-us", "g9-ca", "g9-uk", "g9-de", "g9-fr",
        "g9-nl", "g9-au", "g9-jp", "g9-cn"
    ] = Field(..., description="Subscription tier")
    project_name: str = Field(..., description="Exact project name to deprovision")
    justification: str = Field(..., description="Decommission justification for audit trail")


class DriftDetectionRequest(BaseModel):
    hub: Optional[Literal["amr", "emea", "apac", ""]] = Field(
        "", description="Hub to check — blank scans all hubs"
    )
