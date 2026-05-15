import httpx
from typing import Optional
from fastapi import HTTPException

from ..config import settings

GITHUB_API = "https://api.github.com"


def _headers() -> dict:
    return {
        "Authorization": f"Bearer {settings.github_token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }


async def dispatch_workflow(workflow_filename: str, inputs: dict) -> dict:
    url = (
        f"{GITHUB_API}/repos/{settings.github_owner}/{settings.github_repo}"
        f"/actions/workflows/{workflow_filename}/dispatches"
    )
    payload = {"ref": settings.github_ref, "inputs": inputs}

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(url, headers=_headers(), json=payload)

    if response.status_code == 422:
        raise HTTPException(status_code=422, detail="GitHub rejected the payload — check input values.")
    if response.status_code == 404:
        raise HTTPException(status_code=404, detail=f"Workflow '{workflow_filename}' not found in the repo.")
    if response.status_code == 401:
        raise HTTPException(status_code=401, detail="GitHub token is invalid or expired.")
    if not response.is_success:
        raise HTTPException(status_code=502, detail=f"GitHub API error {response.status_code}: {response.text}")

    return {
        "status": "triggered",
        "message": f"Workflow '{workflow_filename}' dispatched on ref '{settings.github_ref}'.",
        "workflow": workflow_filename,
        "ref": settings.github_ref,
    }


async def list_workflow_runs(workflow_id: Optional[str] = None, per_page: int = 25) -> dict:
    url = f"{GITHUB_API}/repos/{settings.github_owner}/{settings.github_repo}/actions/runs"
    params: dict = {"per_page": per_page}
    if workflow_id:
        params["workflow_id"] = workflow_id

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(url, headers=_headers(), params=params)

    if not response.is_success:
        raise HTTPException(status_code=502, detail=f"GitHub API error {response.status_code}: {response.text}")

    data = response.json()
    runs = [
        {
            "id": r["id"],
            "name": r.get("name"),
            "workflow_id": r.get("workflow_id"),
            "status": r.get("status"),
            "conclusion": r.get("conclusion"),
            "created_at": r.get("created_at"),
            "updated_at": r.get("updated_at"),
            "html_url": r.get("html_url"),
            "head_branch": r.get("head_branch"),
            "display_title": r.get("display_title"),
            "run_number": r.get("run_number"),
        }
        for r in data.get("workflow_runs", [])
    ]
    return {"total_count": data.get("total_count", 0), "runs": runs}


async def get_workflow_run(run_id: int) -> dict:
    url = f"{GITHUB_API}/repos/{settings.github_owner}/{settings.github_repo}/actions/runs/{run_id}"

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(url, headers=_headers())

    if response.status_code == 404:
        raise HTTPException(status_code=404, detail=f"Run {run_id} not found.")
    if not response.is_success:
        raise HTTPException(status_code=502, detail=f"GitHub API error {response.status_code}: {response.text}")

    r = response.json()
    return {
        "id": r["id"],
        "name": r.get("name"),
        "workflow_id": r.get("workflow_id"),
        "status": r.get("status"),
        "conclusion": r.get("conclusion"),
        "created_at": r.get("created_at"),
        "updated_at": r.get("updated_at"),
        "html_url": r.get("html_url"),
        "head_branch": r.get("head_branch"),
        "display_title": r.get("display_title"),
        "run_number": r.get("run_number"),
    }
