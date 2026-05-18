"use client";

import { useState } from "react";
import { Trash2, AlertTriangle, Send } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/Card";
import { Alert } from "@/components/ui/Alert";
import { LoadingSpinner } from "@/components/ui/LoadingSpinner";
import { api } from "@/lib/api";
import { TIERS, TIER_GROUPS, type TierValue, type Hub } from "@/lib/tiers";
import type { WorkflowDispatchResponse } from "@/lib/types";

interface FormState {
  hub: Hub | "";
  subscription_tier: TierValue | "";
  project_name: string;
  justification: string;
  confirmed: boolean;
}

const defaults: FormState = { hub: "", subscription_tier: "", project_name: "", justification: "", confirmed: false };

export default function DeprovisionPage() {
  const [form, setForm] = useState<FormState>(defaults);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<WorkflowDispatchResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  function set<K extends keyof FormState>(k: K, v: FormState[K]) {
    setForm((f) => ({ ...f, [k]: v }));
    setResult(null);
    setError(null);
  }

  const derivedProjectName =
    form.hub && form.subscription_tier ? `${form.hub}-${form.subscription_tier}-` : "";

  const canSubmit =
    form.hub && form.subscription_tier && form.project_name &&
    form.justification.trim().length >= 20 && form.confirmed;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    setLoading(true);
    setResult(null);
    setError(null);
    try {
      const res = await api.deprovisionProject({
        hub: form.hub as Hub,
        subscription_tier: form.subscription_tier as TierValue,
        project_name: form.project_name,
        justification: form.justification,
      });
      setResult(res);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="max-w-2xl mx-auto space-y-5">
      <div>
        <h2 className="page-heading flex items-center gap-2">
          <Trash2 size={22} className="text-red-600" /> Deprovision Foundry Project
        </h2>
        <p className="page-subheading">
          Removes RBAC assignments and deletes the Foundry project resource. Shared services and
          the parent Foundry account are NOT affected.
          Triggers <code className="rounded bg-kpmg-gray px-1 py-0.5 text-xs font-mono">deprovision-project.yml</code>.
        </p>
      </div>

      <div className="flex gap-3 rounded-xl border border-red-200 bg-red-50 p-4">
        <AlertTriangle size={18} className="shrink-0 text-red-600 mt-0.5" />
        <div className="text-sm text-red-700">
          <p className="font-bold">Destructive operation</p>
          <p className="mt-0.5 text-xs leading-relaxed">
            This permanently deletes the Foundry project and all its RBAC assignments.
            Log Analytics data is retained per workspace retention policy. This cannot be undone.
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-5">
        <Card>
          <CardHeader><CardTitle>Identify Project</CardTitle></CardHeader>
          <div className="space-y-4">
            {/* Hub */}
            <div>
              <label className="form-label">Hub Region <span className="text-red-500">*</span></label>
              <div className="grid grid-cols-3 gap-2 mt-1">
                {(["amr", "emea", "apac"] as Hub[]).map((h) => (
                  <button key={h} type="button" onClick={() => set("hub", h)}
                    className={`select-card py-2.5 font-bold text-sm ${form.hub === h ? "select-card-active text-kpmg-blue" : "select-card-inactive text-kpmg-black"}`}>
                    {h.toUpperCase()}
                  </button>
                ))}
              </div>
            </div>

            {/* Tier — grouped */}
            <div>
              <label className="form-label">Foundry Tier <span className="text-red-500">*</span></label>
              <div className="space-y-2 mt-1">
                {TIER_GROUPS.map((group) => (
                  <div key={group}>
                    <p className="text-[10px] font-bold uppercase tracking-widest text-kpmg-gray-dark mb-1">{group}</p>
                    <div className="grid grid-cols-3 gap-1.5">
                      {TIERS.filter((t) => t.group === group).map((t) => (
                        <button
                          key={t.value}
                          type="button"
                          onClick={() => set("subscription_tier", t.value)}
                          className={`rounded-lg border px-2 py-1.5 text-xs font-semibold text-left transition-all ${
                            form.subscription_tier === t.value
                              ? "select-card-active border-kpmg-blue text-kpmg-blue"
                              : "select-card-inactive text-kpmg-black"
                          }`}
                        >
                          {t.flag ? `${t.flag} ` : ""}{t.label}
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Project name */}
            <div>
              <label className="form-label">Project Name <span className="text-red-500">*</span></label>
              <div className="flex items-center gap-0">
                {derivedProjectName && (
                  <span className="rounded-l-lg border border-r-0 border-kpmg-gray-mid bg-kpmg-gray px-3 py-2 text-xs font-mono text-kpmg-gray-dark whitespace-nowrap">
                    {derivedProjectName}
                  </span>
                )}
                <input
                  className={`form-input ${derivedProjectName ? "rounded-l-none" : ""}`}
                  placeholder="dev-tax-assist"
                  value={form.project_name.startsWith(derivedProjectName)
                    ? form.project_name.slice(derivedProjectName.length)
                    : form.project_name}
                  onChange={(e) => set("project_name", derivedProjectName + e.target.value)}
                  required
                />
              </div>
              {form.project_name && (
                <p className="form-hint">Full project name: <code className="font-mono">{form.project_name}</code></p>
              )}
            </div>

            {/* Justification */}
            <div>
              <label className="form-label">Justification <span className="text-red-500">*</span></label>
              <textarea className="form-textarea" rows={3}
                placeholder="Explain why this project is being deprovisioned (min 20 characters)…"
                value={form.justification}
                onChange={(e) => set("justification", e.target.value)}
                required minLength={20} />
              <p className="form-hint">{form.justification.length}/20 chars minimum — stored in workflow run audit log</p>
            </div>
          </div>
        </Card>

        <Card>
          <CardHeader><CardTitle>Confirm Decommission</CardTitle></CardHeader>
          <div className="flex items-start gap-3">
            <input type="checkbox" id="confirm" checked={form.confirmed}
              onChange={(e) => set("confirmed", e.target.checked)}
              className="mt-0.5 h-4 w-4 rounded border-kpmg-gray-mid text-red-600 focus:ring-red-500 cursor-pointer" />
            <label htmlFor="confirm" className="text-sm text-kpmg-black cursor-pointer">
              I confirm that I want to permanently delete project{" "}
              {form.project_name
                ? <code className="font-mono bg-red-50 text-red-700 px-1 rounded">{form.project_name}</code>
                : <span className="italic text-kpmg-gray-dark">{"<project>"}</span>
              }{" "}and all its RBAC assignments. This action is irreversible.
            </label>
          </div>
        </Card>

        {result && <Alert variant="success" title="Deprovision workflow triggered" message={result.message} onDismiss={() => setResult(null)} />}
        {error && <Alert variant="error" title="Failed to trigger workflow" message={error} onDismiss={() => setError(null)} />}

        <div className="flex justify-end">
          <button type="submit" className="btn-danger" disabled={loading || !canSubmit}>
            {loading ? <LoadingSpinner size={16} /> : <Trash2 size={16} />}
            {loading ? "Triggering…" : "Deprovision Project"}
          </button>
        </div>
      </form>
    </div>
  );
}
