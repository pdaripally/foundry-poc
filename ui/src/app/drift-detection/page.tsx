"use client";

import { useState } from "react";
import { ShieldCheck, Globe, Send } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/Card";
import { Alert } from "@/components/ui/Alert";
import { LoadingSpinner } from "@/components/ui/LoadingSpinner";
import { api } from "@/lib/api";
import type { WorkflowDispatchResponse } from "@/lib/types";

type HubFilter = "" | "amr" | "emea" | "apac";

const hubOptions: { value: HubFilter; label: string; desc: string; flag?: string }[] = [
  { value: "", label: "All Hubs", desc: "Scan AMR + EMEA + APAC simultaneously", flag: "🌍" },
  { value: "amr", label: "AMR only", desc: "East US 2", flag: "🇺🇸" },
  { value: "emea", label: "EMEA only", desc: "West Europe", flag: "🇪🇺" },
  { value: "apac", label: "APAC only", desc: "Southeast Asia", flag: "🌏" },
];

export default function DriftDetectionPage() {
  const [hub, setHub] = useState<HubFilter>("");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<WorkflowDispatchResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setResult(null);
    setError(null);
    try {
      const res = await api.driftDetection({ hub });
      setResult(res);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="max-w-xl mx-auto space-y-5">
      <div>
        <h2 className="page-heading flex items-center gap-2">
          <ShieldCheck size={22} className="text-amber-600" /> Drift Detection
        </h2>
        <p className="page-subheading">
          Runs Bicep <code className="rounded bg-kpmg-gray px-1 py-0.5 text-xs font-mono">what-if</code> against
          live infrastructure. Surfaces resources that deviate from the declared IaC state without making changes.
          Triggers <code className="rounded bg-kpmg-gray px-1 py-0.5 text-xs font-mono">drift-detection.yml</code>.
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-1.5">
            <Globe size={13} /> What will be scanned
          </CardTitle>
        </CardHeader>
        <div className="space-y-2 text-sm text-kpmg-gray-dark">
          <p>For each hub and subscription tier selected, the workflow runs:</p>
          <ul className="list-disc pl-4 space-y-1 text-xs">
            <li>
              <code className="font-mono">az deployment sub what-if</code> against{" "}
              <code className="font-mono">infra/hubs/mfs-sub.bicep</code>
            </li>
            <li>
              <code className="font-mono">az deployment sub what-if</code> against{" "}
              <code className="font-mono">infra/hubs/tax-sub.bicep</code>
            </li>
          </ul>
          <p className="text-xs">
            If drift is detected, a GitHub Issue is automatically opened with a summary of the changed resources.
            Review the workflow run logs for the full what-if output.
          </p>
        </div>
      </Card>

      <form onSubmit={handleSubmit} className="space-y-5">
        <Card>
          <CardHeader><CardTitle>Scope</CardTitle></CardHeader>
          <div className="grid grid-cols-2 gap-3">
            {hubOptions.map((h) => (
              <button
                key={h.value}
                type="button"
                onClick={() => { setHub(h.value); setResult(null); setError(null); }}
                className={`select-card text-left ${hub === h.value ? "select-card-active" : "select-card-inactive"}`}
              >
                <div className="flex items-center gap-2">
                  {h.flag && <span className="text-lg">{h.flag}</span>}
                  <div>
                    <p className={`text-sm font-bold ${hub === h.value ? "text-kpmg-blue" : "text-kpmg-black"}`}>
                      {h.label}
                    </p>
                    <p className="text-xs text-kpmg-gray-dark">{h.desc}</p>
                  </div>
                </div>
              </button>
            ))}
          </div>
        </Card>

        {result && (
          <Alert
            variant="success"
            title="Drift detection triggered"
            message={result.message}
            onDismiss={() => setResult(null)}
          />
        )}
        {error && (
          <Alert variant="error" title="Failed to trigger workflow" message={error} onDismiss={() => setError(null)} />
        )}

        <div className="flex items-center justify-between">
          <p className="text-xs text-kpmg-gray-dark">
            This is a read-only operation. No resources will be created or modified.
          </p>
          <button type="submit" className="btn-secondary" disabled={loading}>
            {loading ? <LoadingSpinner size={16} /> : <Send size={16} />}
            {loading ? "Triggering…" : "Run Drift Check"}
          </button>
        </div>
      </form>
    </div>
  );
}
