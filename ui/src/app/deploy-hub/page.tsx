"use client";

import { useState } from "react";
import { Rocket, Globe, Send, Eye } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/Card";
import { Alert } from "@/components/ui/Alert";
import { LoadingSpinner } from "@/components/ui/LoadingSpinner";
import { api } from "@/lib/api";
import type { WorkflowDispatchResponse } from "@/lib/types";

type Hub = "amr" | "emea" | "apac";
type Env = "dev" | "staging" | "prod";

const hubs: { value: Hub; label: string; location: string; flag: string }[] = [
  { value: "amr", label: "AMR", location: "East US 2 (eastus2)", flag: "🇺🇸" },
  { value: "emea", label: "EMEA", location: "West Europe (westeurope)", flag: "🇪🇺" },
  { value: "apac", label: "APAC", location: "Southeast Asia (southeastasia)", flag: "🌏" },
];

const envs: { value: Env; label: string; description: string; color: string }[] = [
  { value: "dev", label: "Dev", description: "Development — public Foundry access, relaxed policy", color: "text-emerald-600" },
  { value: "staging", label: "Staging", description: "Staging — mirrors prod config for pre-release testing", color: "text-amber-600" },
  { value: "prod", label: "Prod", description: "Production — private endpoints, full policy enforcement", color: "text-red-600" },
];

interface FormState {
  hub: Hub | "";
  environment: Env;
  dry_run: boolean;
}

export default function DeployHubPage() {
  const [form, setForm] = useState<FormState>({ hub: "", environment: "dev", dry_run: false });
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<WorkflowDispatchResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  const canSubmit = !!form.hub;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.hub) return;
    setLoading(true);
    setResult(null);
    setError(null);
    try {
      const res = await api.deployHub({
        hub: form.hub,
        environment: form.environment,
        dry_run: form.dry_run,
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
          <Rocket size={22} className="text-kpmg-blue" /> Deploy Regional Hub
        </h2>
        <p className="page-subheading">
          Deploys all 3 subscriptions for the chosen hub in order: MFS → Tax → Shared Services (APIM).
          Triggers <code className="rounded bg-kpmg-gray px-1 py-0.5 text-xs font-mono">deploy-hub.yml</code>.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-5">
        {/* Hub selection */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-1.5">
              <Globe size={13} /> Select Hub Region
            </CardTitle>
          </CardHeader>
          <div className="grid grid-cols-3 gap-3">
            {hubs.map((h) => (
              <button
                key={h.value}
                type="button"
                onClick={() => { setForm((f) => ({ ...f, hub: h.value })); setResult(null); setError(null); }}
                className={`select-card flex flex-col items-center gap-2 text-center ${
                  form.hub === h.value ? "select-card-active" : "select-card-inactive"
                }`}
              >
                <span className="text-2xl">{h.flag}</span>
                <span className={`text-base font-bold ${form.hub === h.value ? "text-kpmg-blue" : "text-kpmg-black"}`}>
                  {h.label}
                </span>
                <span className="text-[10px] text-kpmg-gray-dark leading-tight">{h.location}</span>
              </button>
            ))}
          </div>
        </Card>

        {/* What gets deployed */}
        {form.hub && (
          <Card>
            <CardHeader><CardTitle>Subscriptions to be deployed</CardTitle></CardHeader>
            <div className="space-y-2.5">
              {[
                { tier: "MFS Shared", name: `foundry-mfs-${form.hub}`, rg: `rg-foundry-mfs-${form.hub}`, desc: "Foundry instance + monitoring + networking + shared services + approved models policy" },
                { tier: "GF Tax", name: `foundry-tax-${form.hub}`, rg: `rg-foundry-tax-${form.hub}`, desc: "Foundry instance + monitoring + networking + shared services + approved models policy" },
                { tier: "Shared Services", name: `apim-foundry-${form.hub}`, rg: `rg-foundry-shared-${form.hub}`, desc: "APIM gateway routing to MFS and Tax Foundry endpoints via managed identity" },
              ].map((s, i) => (
                <div key={i} className="rounded-lg bg-kpmg-gray px-3 py-2.5">
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="text-[10px] font-bold bg-kpmg-blue text-white rounded px-1.5 py-0.5">
                      {i + 1}
                    </span>
                    <span className="text-sm font-semibold text-kpmg-black">{s.tier}</span>
                    <code className="ml-auto text-[10px] font-mono text-kpmg-gray-dark">{s.name}</code>
                  </div>
                  <p className="text-xs text-kpmg-gray-dark pl-7">{s.desc}</p>
                </div>
              ))}
            </div>
          </Card>
        )}

        {/* Environment + options */}
        <Card>
          <CardHeader><CardTitle>Deployment Configuration</CardTitle></CardHeader>
          <div className="space-y-4">
            <div>
              <label className="form-label">Environment</label>
              <div className="grid grid-cols-3 gap-2 mt-1">
                {envs.map((e) => (
                  <button
                    key={e.value}
                    type="button"
                    onClick={() => setForm((f) => ({ ...f, environment: e.value }))}
                    className={`select-card text-left ${
                      form.environment === e.value ? "select-card-active" : "select-card-inactive"
                    }`}
                  >
                    <p className={`text-sm font-bold ${form.environment === e.value ? "text-kpmg-blue" : e.color}`}>
                      {e.label}
                    </p>
                    <p className="text-xs text-kpmg-gray-dark mt-0.5 leading-tight">{e.description}</p>
                  </button>
                ))}
              </div>
              {form.environment === "prod" && (
                <p className="form-hint text-amber-700 mt-2">
                  ⚠ Prod deploys Foundry with private endpoints and full Azure Policy enforcement. Ensure private networking is configured.
                </p>
              )}
            </div>

            <div className="flex items-center gap-3 rounded-lg border border-kpmg-gray-mid p-3">
              <input
                type="checkbox"
                id="dry_run"
                checked={form.dry_run}
                onChange={(e) => setForm((f) => ({ ...f, dry_run: e.target.checked }))}
                className="h-4 w-4 rounded border-kpmg-gray-mid text-kpmg-blue focus:ring-kpmg-light-blue cursor-pointer"
              />
              <label htmlFor="dry_run" className="flex items-center gap-2 cursor-pointer flex-1">
                <Eye size={14} className="text-kpmg-gray-dark" />
                <div>
                  <p className="text-sm font-semibold text-kpmg-black">Dry run (what-if only)</p>
                  <p className="text-xs text-kpmg-gray-dark">Preview changes without deploying any resources</p>
                </div>
              </label>
            </div>
          </div>
        </Card>

        {result && (
          <Alert
            variant="success"
            title={form.dry_run ? "What-if triggered" : "Hub deployment triggered"}
            message={result.message}
            onDismiss={() => setResult(null)}
          />
        )}
        {error && (
          <Alert variant="error" title="Failed to trigger workflow" message={error} onDismiss={() => setError(null)} />
        )}

        <div className="flex justify-end">
          <button type="submit" className={form.dry_run ? "btn-secondary" : "btn-primary"} disabled={loading || !canSubmit}>
            {loading ? <LoadingSpinner size={16} /> : form.dry_run ? <Eye size={16} /> : <Send size={16} />}
            {loading ? "Triggering…" : form.dry_run ? "Run What-If" : "Deploy Hub"}
          </button>
        </div>
      </form>
    </div>
  );
}
