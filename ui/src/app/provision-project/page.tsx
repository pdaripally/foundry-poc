"use client";

import { useState } from "react";
import { FolderPlus, Send, Lock, Users, ShieldCheck } from "lucide-react";
import { Card, CardHeader, CardTitle } from "@/components/ui/Card";
import { Alert } from "@/components/ui/Alert";
import { LoadingSpinner } from "@/components/ui/LoadingSpinner";
import { api } from "@/lib/api";
import { TIERS, TIER_GROUPS, type TierValue, type Hub } from "@/lib/tiers";
import type { WorkflowDispatchResponse } from "@/lib/types";

type Env = "nonprod" | "uat" | "prod";
type DataClass = "public" | "internal" | "confidential" | "restricted";

const dataClassConfig: Record<DataClass, { color: string; hint: string }> = {
  public:       { color: "bg-emerald-100 text-emerald-700 border-emerald-300", hint: "No PII or sensitive data" },
  internal:     { color: "bg-blue-100 text-blue-700 border-blue-300",          hint: "Internal KPMG use only" },
  confidential: { color: "bg-amber-100 text-amber-700 border-amber-300",       hint: "Restricted to project members" },
  restricted:   { color: "bg-red-100 text-red-700 border-red-300",             hint: "Highest sensitivity — requires compliance approval" },
};

interface FormState {
  hub: Hub | "";
  subscription_tier: TierValue | "";
  workload_name: string;
  environment: Env;
  data_classification: DataClass;
  cost_center: string;
  project_admin_group_oid: string;
  project_user_group_oid: string;
}

const defaults: FormState = {
  hub: "", subscription_tier: "", workload_name: "", environment: "nonprod",
  data_classification: "internal", cost_center: "", project_admin_group_oid: "", project_user_group_oid: "",
};

export default function ProvisionProjectPage() {
  const [form, setForm] = useState<FormState>(defaults);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<WorkflowDispatchResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  function set<K extends keyof FormState>(k: K, v: FormState[K]) {
    setForm((f) => ({ ...f, [k]: v }));
    setResult(null);
    setError(null);
  }

  const projectNamePreview =
    form.hub && form.subscription_tier && form.workload_name
      ? `${form.hub}-${form.subscription_tier}-${form.environment}-${form.workload_name}`
      : null;

  const foundryInstance =
    form.hub && form.subscription_tier
      ? `foundry-${form.subscription_tier}-${form.hub}`
      : null;

  const isNonprodWithRestrictedData =
    form.environment === "nonprod" && ["confidential", "restricted"].includes(form.data_classification);

  const canSubmit =
    form.hub && form.subscription_tier && form.workload_name &&
    form.cost_center && form.project_admin_group_oid && !isNonprodWithRestrictedData;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    setLoading(true);
    setResult(null);
    setError(null);
    try {
      const res = await api.provisionProject({
        hub: form.hub as Hub,
        subscription_tier: form.subscription_tier as TierValue,
        workload_name: form.workload_name,
        environment: form.environment,
        data_classification: form.data_classification,
        cost_center: form.cost_center,
        project_admin_group_oid: form.project_admin_group_oid,
        project_user_group_oid: form.project_user_group_oid || undefined,
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
          <FolderPlus size={22} className="text-emerald-600" /> Provision Foundry Project
        </h2>
        <p className="page-subheading">
          Runs OPA policy checks then deploys a new Foundry project with RBAC isolation.
          Triggers <code className="rounded bg-kpmg-gray px-1 py-0.5 text-xs font-mono">provision-foundry-project.yml</code>.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-5">
        {/* Hub + Tier */}
        <Card>
          <CardHeader><CardTitle>Target Foundry Instance</CardTitle></CardHeader>
          <div className="space-y-4">
            {/* Hub */}
            <div>
              <label className="form-label">Hub Region</label>
              <div className="grid grid-cols-3 gap-2 mt-1">
                {(["amr", "emea", "apac"] as Hub[]).map((h) => (
                  <button key={h} type="button" onClick={() => set("hub", h)}
                    className={`select-card py-3 font-bold text-sm ${form.hub === h ? "select-card-active text-kpmg-blue" : "select-card-inactive text-kpmg-black"}`}>
                    {h.toUpperCase()}
                  </button>
                ))}
              </div>
            </div>

            {/* Tier — grouped */}
            <div>
              <label className="form-label">Foundry Tier (Resource Group)</label>
              <div className="space-y-3 mt-1">
                {TIER_GROUPS.map((group) => (
                  <div key={group}>
                    <p className="text-[10px] font-bold uppercase tracking-widest text-kpmg-gray-dark mb-1.5">{group}</p>
                    <div className="grid grid-cols-2 gap-2">
                      {TIERS.filter((t) => t.group === group).map((t) => (
                        <button
                          key={t.value}
                          type="button"
                          onClick={() => set("subscription_tier", t.value)}
                          className={`select-card text-left py-2 ${form.subscription_tier === t.value ? "select-card-active" : "select-card-inactive"}`}
                        >
                          <p className={`text-xs font-bold ${form.subscription_tier === t.value ? "text-kpmg-blue" : "text-kpmg-black"}`}>
                            {t.flag ? `${t.flag} ` : ""}{t.label}
                          </p>
                          {form.hub && (
                            <p className="text-[10px] font-mono text-kpmg-gray-dark mt-0.5 truncate">
                              foundry-{t.value}-{form.hub}
                            </p>
                          )}
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {foundryInstance && (
              <div className="flex items-center gap-2 text-xs bg-kpmg-pale-blue rounded-lg px-3 py-2">
                <ShieldCheck size={13} className="text-kpmg-blue shrink-0" />
                <span className="text-kpmg-gray-dark">Target Foundry instance:</span>
                <code className="font-mono font-semibold text-kpmg-blue">{foundryInstance}</code>
              </div>
            )}
          </div>
        </Card>

        {/* Project config */}
        <Card>
          <CardHeader><CardTitle>Project Configuration</CardTitle></CardHeader>
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="form-label">Workload Name <span className="text-red-500">*</span></label>
                <input
                  className="form-input"
                  placeholder="e.g. tax-assist"
                  value={form.workload_name}
                  onChange={(e) => set("workload_name", e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""))}
                  required maxLength={20}
                />
                <p className="form-hint">Lowercase + hyphens, max 20 chars</p>
              </div>
              <div>
                <label className="form-label">Cost Center <span className="text-red-500">*</span></label>
                <input className="form-input" placeholder="e.g. 135355" value={form.cost_center}
                  onChange={(e) => set("cost_center", e.target.value)} required />
              </div>
            </div>

            <div>
              <label className="form-label">Environment</label>
              <div className="flex gap-2 mt-1">
                {(["nonprod", "uat", "prod"] as Env[]).map((env) => (
                  <button key={env} type="button" onClick={() => set("environment", env)}
                    className={`chip ${form.environment === env ? "chip-active" : "chip-inactive"}`}>
                    {env}
                  </button>
                ))}
              </div>
              {form.environment === "prod" && (
                <p className="form-hint text-amber-700 mt-1">
                  ⚠ Prod deployments automatically revoke developer standing access after provisioning.
                </p>
              )}
            </div>

            <div>
              <label className="form-label">Data Classification</label>
              <div className="grid grid-cols-4 gap-2 mt-1">
                {(Object.keys(dataClassConfig) as DataClass[]).map((dc) => (
                  <button key={dc} type="button" onClick={() => set("data_classification", dc)}
                    className={`rounded-lg border px-2 py-2 text-xs font-semibold capitalize transition-all ${
                      form.data_classification === dc
                        ? dataClassConfig[dc].color + " ring-2 ring-offset-1 ring-current"
                        : "border-kpmg-gray-mid bg-white text-kpmg-gray-dark hover:border-kpmg-blue"
                    }`}>
                    {dc}
                  </button>
                ))}
              </div>
              <p className="form-hint mt-1">{dataClassConfig[form.data_classification].hint}</p>
              {isNonprodWithRestrictedData && (
                <p className="mt-1 text-xs font-semibold text-red-600">
                  ✕ {form.data_classification} data is not allowed in dev (OPA policy).
                </p>
              )}
            </div>

            {projectNamePreview && (
              <div className="rounded-lg bg-kpmg-gray border border-kpmg-gray-mid px-3 py-2">
                <p className="text-[10px] font-bold uppercase tracking-widest text-kpmg-gray-dark mb-0.5">Project name preview</p>
                <code className="text-sm font-mono text-kpmg-blue font-semibold">{projectNamePreview}</code>
              </div>
            )}
          </div>
        </Card>

        {/* RBAC */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-1.5"><Lock size={13} /> RBAC Assignments</CardTitle>
          </CardHeader>
          <div className="space-y-4">
            <div className="rounded-lg bg-kpmg-pale-blue border border-kpmg-light-blue/30 p-3 text-xs text-kpmg-gray-dark space-y-1">
              <p className="font-semibold text-kpmg-blue">Governance model</p>
              <p><strong>Project Admin</strong> — manages project settings and users. Cannot provision models.</p>
              <p><strong>Project User</strong> — runs inference, agents, evaluations. Cannot provision models.</p>
              <p>Models are hub-managed. New models require a separate approval workflow.</p>
            </div>
            <div>
              <label className="form-label">
                <Users size={11} className="inline mr-1" />
                Project Admin Group OID <span className="text-red-500">*</span>
              </label>
              <input className="form-input font-mono text-xs"
                placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                value={form.project_admin_group_oid}
                onChange={(e) => set("project_admin_group_oid", e.target.value)}
                required pattern="^[0-9a-fA-F-]{36}$"
                title="Must be a valid Entra ID object ID (UUID)" />
              <p className="form-hint">Entra ID group object ID assigned Foundry Project Admin role</p>
            </div>
            <div>
              <label className="form-label">
                <Users size={11} className="inline mr-1" />
                Project Users Group OID
              </label>
              <input className="form-input font-mono text-xs"
                placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (optional)"
                value={form.project_user_group_oid}
                onChange={(e) => set("project_user_group_oid", e.target.value)} />
              <p className="form-hint">Optional — Entra ID group assigned Foundry Project User role</p>
            </div>
          </div>
        </Card>

        {result && <Alert variant="success" title="Project provisioning triggered" message={result.message} onDismiss={() => setResult(null)} />}
        {error && <Alert variant="error" title="Failed to trigger workflow" message={error} onDismiss={() => setError(null)} />}

        <div className="flex justify-end">
          <button type="submit" className="btn-primary" disabled={loading || !canSubmit}>
            {loading ? <LoadingSpinner size={16} /> : <Send size={16} />}
            {loading ? "Triggering…" : "Provision Project"}
          </button>
        </div>
      </form>
    </div>
  );
}
