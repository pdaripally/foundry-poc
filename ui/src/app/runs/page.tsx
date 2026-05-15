"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { History, RefreshCw, ExternalLink, Filter } from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import { Card } from "@/components/ui/Card";
import { LoadingSpinner } from "@/components/ui/LoadingSpinner";
import { api } from "@/lib/api";
import { timeAgo } from "@/lib/utils";
import type { WorkflowRun } from "@/lib/types";

const WORKFLOW_OPTIONS = [
  { value: "", label: "All workflows" },
  { value: "deploy-hub.yml", label: "deploy-hub.yml" },
  { value: "vend-foundry-project.yml", label: "vend-foundry-project.yml" },
  { value: "deprovision-project.yml", label: "deprovision-project.yml" },
  { value: "drift-detection.yml", label: "drift-detection.yml" },
];

const PER_PAGE = 30;
const POLL_INTERVAL_MS = 30_000;

export default function RunsPage() {
  const [runs, setRuns] = useState<WorkflowRun[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [workflow, setWorkflow] = useState("");
  const [error, setError] = useState<string | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const fetchRuns = useCallback(
    async (silent = false) => {
      if (!silent) setLoading(true);
      else setRefreshing(true);
      setError(null);
      try {
        const res = await api.listRuns(workflow || undefined, PER_PAGE);
        setRuns(res.runs);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load runs");
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [workflow],
  );

  // Fetch whenever filter changes
  useEffect(() => {
    fetchRuns();
  }, [fetchRuns]);

  // Auto-refresh when any run is in-progress or queued
  useEffect(() => {
    const hasActive = runs.some((r) => r.status === "in_progress" || r.status === "queued");
    if (timerRef.current) clearTimeout(timerRef.current);
    if (hasActive) {
      timerRef.current = setTimeout(() => fetchRuns(true), POLL_INTERVAL_MS);
    }
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, [runs, fetchRuns]);

  const hasActive = runs.some((r) => r.status === "in_progress" || r.status === "queued");

  return (
    <div className="max-w-5xl mx-auto space-y-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="page-heading flex items-center gap-2">
            <History size={22} className="text-purple-700" /> Workflow Run History
          </h2>
          <p className="page-subheading">
            All GitHub Actions executions across every workflow.
            {hasActive && (
              <span className="ml-2 inline-flex items-center gap-1 text-kpmg-blue">
                <span className="inline-block h-1.5 w-1.5 rounded-full bg-kpmg-blue animate-pulse" />
                Auto-refreshing every 30 s
              </span>
            )}
          </p>
        </div>

        <button
          type="button"
          onClick={() => fetchRuns(true)}
          disabled={refreshing}
          className="btn-secondary shrink-0"
        >
          {refreshing ? <LoadingSpinner size={14} /> : <RefreshCw size={14} />}
          Refresh
        </button>
      </div>

      {/* Filter bar */}
      <div className="flex items-center gap-2">
        <Filter size={13} className="text-kpmg-gray-dark shrink-0" />
        <label className="text-xs font-semibold text-kpmg-gray-dark whitespace-nowrap">
          Filter by workflow
        </label>
        <select
          className="form-select max-w-xs"
          value={workflow}
          onChange={(e) => setWorkflow(e.target.value)}
        >
          {WORKFLOW_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </div>

      <Card className="overflow-hidden p-0">
        {loading ? (
          <div className="flex items-center justify-center gap-2 py-16 text-sm text-kpmg-gray-dark">
            <LoadingSpinner size={18} />
            Loading runs…
          </div>
        ) : error ? (
          <div className="py-12 text-center text-sm text-red-600">{error}</div>
        ) : runs.length === 0 ? (
          <div className="py-12 text-center text-sm text-kpmg-gray-dark">
            No workflow runs found{workflow ? ` for ${workflow}` : ""}.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-kpmg-gray-mid bg-kpmg-gray text-left">
                  <th className="px-4 py-2.5 text-[10px] font-bold uppercase tracking-wider text-kpmg-gray-dark w-16">
                    Run #
                  </th>
                  <th className="px-4 py-2.5 text-[10px] font-bold uppercase tracking-wider text-kpmg-gray-dark">
                    Workflow / Title
                  </th>
                  <th className="px-4 py-2.5 text-[10px] font-bold uppercase tracking-wider text-kpmg-gray-dark w-36">
                    Status
                  </th>
                  <th className="px-4 py-2.5 text-[10px] font-bold uppercase tracking-wider text-kpmg-gray-dark w-36">
                    Started
                  </th>
                  <th className="px-4 py-2.5 text-[10px] font-bold uppercase tracking-wider text-kpmg-gray-dark w-20">
                    Logs
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-kpmg-gray-mid">
                {runs.map((run) => (
                  <RunRow key={run.id} run={run} />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      {runs.length > 0 && (
        <p className="text-center text-xs text-kpmg-gray-dark">
          Showing {runs.length} most recent run{runs.length !== 1 ? "s" : ""}
          {workflow ? ` for ${workflow}` : " across all workflows"}.
        </p>
      )}
    </div>
  );
}

function RunRow({ run }: { run: WorkflowRun }) {
  const statusValue = run.status === "completed" ? run.conclusion : run.status;
  const isActive = run.status === "in_progress" || run.status === "queued";

  return (
    <tr className={`group transition-colors hover:bg-kpmg-gray/60 ${isActive ? "bg-blue-50/40" : ""}`}>
      <td className="px-4 py-3 font-mono text-xs text-kpmg-gray-dark">
        #{run.run_number}
      </td>
      <td className="px-4 py-3 min-w-0">
        <p className="font-semibold text-kpmg-black truncate max-w-sm">
          {run.display_title ?? run.name ?? `Run #${run.run_number}`}
        </p>
        {run.name && run.display_title && run.name !== run.display_title && (
          <p className="text-xs text-kpmg-gray-dark font-mono mt-0.5 truncate max-w-sm">
            {run.name}
          </p>
        )}
      </td>
      <td className="px-4 py-3">
        <Badge value={statusValue} />
      </td>
      <td className="px-4 py-3 text-xs text-kpmg-gray-dark whitespace-nowrap">
        {timeAgo(run.created_at)}
      </td>
      <td className="px-4 py-3">
        {run.html_url ? (
          <a
            href={run.html_url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs font-medium text-kpmg-blue hover:text-kpmg-mid-blue"
          >
            View <ExternalLink size={11} />
          </a>
        ) : (
          <span className="text-xs text-kpmg-gray-dark">—</span>
        )}
      </td>
    </tr>
  );
}
