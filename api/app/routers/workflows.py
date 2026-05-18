from fastapi import APIRouter, Query
from typing import Optional

from ..models.requests import (
    DeployHubRequest,
    ProvisionProjectRequest,
    DeprovisionProjectRequest,
    DriftDetectionRequest,
)
from ..models.responses import WorkflowDispatchResponse, WorkflowRunsResponse, WorkflowRun
from ..services import github

router = APIRouter(prefix="/api/workflows", tags=["workflows"])


@router.post(
    "/deploy-hub",
    response_model=WorkflowDispatchResponse,
    summary="Deploy all 3 subscriptions for a regional hub",
)
async def deploy_hub(payload: DeployHubRequest):
    return await github.dispatch_workflow(
        "deploy-hub.yml",
        {
            "hub": payload.hub,
            "environment": payload.environment,
            "dry_run": str(payload.dry_run).lower(),
        },
    )


@router.post(
    "/provision-project",
    response_model=WorkflowDispatchResponse,
    summary="Provision a new Foundry project with RBAC isolation",
)
async def provision_project(payload: ProvisionProjectRequest):
    return await github.dispatch_workflow(
        "provision-foundry-project.yml",
        {
            "hub": payload.hub,
            "subscription_tier": payload.subscription_tier,
            "workload_name": payload.workload_name,
            "environment": payload.environment,
            "data_classification": payload.data_classification,
            "cost_center": payload.cost_center,
            "project_admin_group_oid": payload.project_admin_group_oid,
            "project_user_group_oid": payload.project_user_group_oid or "",
        },
    )


@router.post(
    "/deprovision-project",
    response_model=WorkflowDispatchResponse,
    summary="Deprovision (delete) a Foundry project and its RBAC assignments",
)
async def deprovision_project(payload: DeprovisionProjectRequest):
    return await github.dispatch_workflow(
        "deprovision-project.yml",
        {
            "hub": payload.hub,
            "subscription_tier": payload.subscription_tier,
            "project_name": payload.project_name,
            "justification": payload.justification,
        },
    )


@router.post(
    "/drift-detection",
    response_model=WorkflowDispatchResponse,
    summary="Run IaC drift detection (what-if) against hub subscriptions",
)
async def drift_detection(payload: DriftDetectionRequest):
    return await github.dispatch_workflow(
        "drift-detection.yml",
        {"hub": payload.hub or ""},
    )


@router.get(
    "/runs",
    response_model=WorkflowRunsResponse,
    summary="List recent GitHub Actions workflow runs",
)
async def list_runs(
    workflow_id: Optional[str] = Query(None, description="Filter by workflow filename"),
    per_page: int = Query(25, ge=1, le=100),
):
    return await github.list_workflow_runs(workflow_id=workflow_id, per_page=per_page)


@router.get(
    "/runs/{run_id}",
    response_model=WorkflowRun,
    summary="Get a single workflow run by ID",
)
async def get_run(run_id: int):
    return await github.get_workflow_run(run_id)
