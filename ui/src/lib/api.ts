import type { WorkflowDispatchResponse, WorkflowRunsResponse, WorkflowRun } from "./types";

const API_BASE =
  process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "") ?? "http://localhost:8000";

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.detail ?? `Request failed: ${res.status}`);
  return data as T;
}

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { cache: "no-store" });
  const data = await res.json();
  if (!res.ok) throw new Error(data.detail ?? `Request failed: ${res.status}`);
  return data as T;
}

export const api = {
  deployHub: (payload: { hub: string; environment: string; dry_run: boolean }) =>
    post<WorkflowDispatchResponse>("/api/workflows/deploy-hub", payload),

  vendProject: (payload: {
    hub: string;
    subscription_tier: string;
    workload_name: string;
    environment: string;
    data_classification: string;
    cost_center: string;
    project_admin_group_oid: string;
    project_user_group_oid?: string;
  }) => post<WorkflowDispatchResponse>("/api/workflows/vend-project", payload),

  deprovisionProject: (payload: {
    hub: string;
    subscription_tier: string;
    project_name: string;
    justification: string;
  }) => post<WorkflowDispatchResponse>("/api/workflows/deprovision-project", payload),

  driftDetection: (payload: { hub: string }) =>
    post<WorkflowDispatchResponse>("/api/workflows/drift-detection", payload),

  listRuns: (workflowId?: string, perPage = 25): Promise<WorkflowRunsResponse> => {
    const qs = new URLSearchParams({ per_page: String(perPage) });
    if (workflowId) qs.set("workflow_id", workflowId);
    return get<WorkflowRunsResponse>(`/api/workflows/runs?${qs}`);
  },

  getRun: (runId: number) => get<WorkflowRun>(`/api/workflows/runs/${runId}`),
};
