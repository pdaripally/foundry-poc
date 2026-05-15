from pydantic import BaseModel
from typing import Optional


class WorkflowDispatchResponse(BaseModel):
    status: str
    message: str
    workflow: str
    ref: str


class WorkflowRun(BaseModel):
    id: int
    name: Optional[str]
    workflow_id: Optional[int]
    status: Optional[str]
    conclusion: Optional[str]
    created_at: Optional[str]
    updated_at: Optional[str]
    html_url: Optional[str]
    head_branch: Optional[str]
    display_title: Optional[str]
    run_number: Optional[int]


class WorkflowRunsResponse(BaseModel):
    total_count: int
    runs: list[WorkflowRun]
