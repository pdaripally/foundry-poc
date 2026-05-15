export interface WorkflowDispatchResponse {
  status: string;
  message: string;
  workflow: string;
  ref: string;
}

export interface WorkflowRun {
  id: number;
  name: string | null;
  workflow_id: number | null;
  status: "queued" | "in_progress" | "completed" | "waiting" | null;
  conclusion: "success" | "failure" | "cancelled" | "skipped" | "timed_out" | null;
  created_at: string | null;
  updated_at: string | null;
  html_url: string | null;
  head_branch: string | null;
  display_title: string | null;
  run_number: number | null;
}

export interface WorkflowRunsResponse {
  total_count: number;
  runs: WorkflowRun[];
}
