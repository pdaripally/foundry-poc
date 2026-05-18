"use client";

import { useState } from "react";
import { Rocket, Globe, Send, Eye } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/Card";
import { Alert } from "@/components/ui/Alert";
import { LoadingSpinner } from "@/components/ui/LoadingSpinner";
import { api } from "@/lib/api";
import { TIERS, TIER_GROUPS, type Hub } from "@/lib/tiers";
import type { WorkflowDispatchResponse } from "@/lib/types";

type Env = "nonprod" | "uat" | "prod";

const hubs: { value: Hub; label: string; location: string; flag: string }[] = [
  { value: "amr",  label: "AMR",  location: "East US 2 (eastus2)",              flag: "🇺🇸" },
  { value: "emea", label: "EMEA", location: "West Europe (westeurope)",          flag: "🇪🇺" },
  { value: "apac", label: "APAC", location: "Southeast Asia (southeastasia)",    flag: "🌏" },
];

const envs: { value: Env; label: string; description: string; color: string }[] = [
  { value: "nonprod",     label: "Nonprod",     description: "Public Foundry access, relaxed policy",          color: "text-emerald-600" },
  { value: "uat", label: "UAT", description: "Mirrors prod config for pre-release testing",     color: "text-amber-600" },
  { value: "prod",    label: "Prod",    description: "Private endpoints, full policy enforcement",      color: "text-red-600" },
];

const SHARED_RG = { label: "Shared (APIM Gateway)", rg: (h: Hub) => `rg-agentops-shared-${h}`, resource: (h: Hub) => `apim-foundry-${h}`, desc: "APIM gateway routing to all 13 Foundry instances via managed identity" };

interface FormState { hub: Hub | ""; environment: Env; dry_run: boolean }

export default function DeployHubPage() {
  const [form, setForm] = useState<FormState>({ hub: "", environment: "nonprod", dry_run: false });
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
      const res = await api.deployHub({ hub: form.hub, environment: form.environment, dry_run: form.dry_run });
      setResult(res);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="max-w-4xl mx-auto space-y-5">
      <div>
        <h2 className="page-heading flex items-center gap-2">
          <Rocket size={22} className="text-kpmg-blue" /> Deploy Regional Hub
        </h2>
        <p className="page-subheading">
          Deploys <strong>14 resource groups</strong> into the shared Azure subscription for the chosen hub —
          13 Foundry instances (deployed in parallel) then the APIM gateway.
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
                className={`select-card flex flex-col items-center gap-2 text-center ${form.hub === h.value ? "select-card-active" : "select-card-inactive"}`}
              >
                <span className="text-2xl">{h.flag}</span>
                <span className={`text-base font-bold ${form.hub === h.value ? "text-kpmg-blue" : "text-kpmg-black"}`}>{h.label}</span>
                <span className="text-[10px] text-kpmg-gray-dark leading-tight">{h.location}</span>
              </button>
            ))}
          </div>
        </Card>

        {/* 14 RG preview */}
        {form.hub && (
          <Card>
            <CardHeader><CardTitle>14 Resource Groups to be deployed</CardTitle></CardHeader>
            <div className="space-y-1.5">
              {TIER_GROUPS.map((group) => (
                <div key={group}>
                  <p className="text-[10px] font-bold uppercase tracking-widest text-kpmg-gray-dark mb-1 mt-2 first:mt-0">{group}</p>
                  <div className="space-y-1">
                    {TIERS.filter((t) => t.group === group).map((t, i) => {
                      const idx = TIERS.indexOf(t) + 1;
                      return (
                        <div key={t.value} className="flex items-center gap-2 rounded-lg bg-kpmg-gray px-3 py-2">
                          <span className="text-[10px] font-bold bg-kpmg-blue text-white rounded px-1.5 py-0.5 shrink-0 w-6 text-center">{idx}</span>
                          <span className="text-sm font-semibold text-kpmg-black shrink-0 w-36">{t.flag ? `${t.flag} ${t.label}` : t.label}</span>
                          <code className="text-[10px] font-mono text-kpmg-gray-dark">rg-agentops-{t.value}-{form.hub}</code>
                          <code className="ml-auto text-[10px] font-mono text-kpmg-gray-dark">foundry-{t.value}-{form.hub}</code>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
              {/* Shared APIM */}
              <div className="mt-2">
                <p className="text-[10px] font-bold uppercase tracking-widest text-kpmg-gray-dark mb-1">Shared Services</p>
                <div className="flex items-center gap-2 rounded-lg border border-kpmg-blue/20 bg-kpmg-pale-blue px-3 py-2">
                  <span className="text-[10px] font-bold bg-kpmg-blue text-white rounded px-1.5 py-0.5 shrink-0 w-6 text-center">14</span>
                  <span className="text-sm font-semibold text-kpmg-blue shrink-0 w-36">{SHARED_RG.label}</span>
                  <code className="text-[10px] font-mono text-kpmg-gray-dark">rg-agentops-shared-{form.hub}</code>
                  <code className="ml-auto text-[10px] font-mono text-kpmg-gray-dark">apim-foundry-{form.hub}</code>
                </div>
              </div>
            </div>
          </Card>
        )}

        {/* Environment + dry run */}
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
                    className={`select-card text-left ${form.environment === e.value ? "select-card-active" : "select-card-inactive"}`}
                  >
                    <p className={`text-sm font-bold ${form.environment === e.value ? "text-kpmg-blue" : e.color}`}>{e.label}</p>
                    <p className="text-xs text-kpmg-gray-dark mt-0.5 leading-tight">{e.description}</p>
                  </button>
                ))}
              </div>
              {form.environment === "prod" && (
                <p className="form-hint text-amber-700 mt-2">
                  ⚠ Prod deploys all Foundry instances with private endpoints and full Azure Policy enforcement.
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
          <Alert variant="success" title={form.dry_run ? "What-if triggered" : "Hub deployment triggered"} message={result.message} onDismiss={() => setResult(null)} />
        )}
        {error && (
          <Alert variant="error" title="Failed to trigger workflow" message={error} onDismiss={() => setError(null)} />
        )}

        <div className="flex justify-end">
          <button type="submit" className={form.dry_run ? "btn-secondary" : "btn-primary"} disabled={loading || !canSubmit}>
            {loading ? <LoadingSpinner size={16} /> : form.dry_run ? <Eye size={16} /> : <Send size={16} />}
            {loading ? "Triggering…" : form.dry_run ? "Run What-If" : "Deploy Hub (14 RGs)"}
          </button>
        </div>
      </form>
    </div>
  );
}
