"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  Rocket, FolderPlus, Trash2, ShieldCheck, History,
  ArrowRight, Globe, Layers, GitBranch, Activity,
} from "lucide-react";
import { Card } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { api } from "@/lib/api";
import { timeAgo } from "@/lib/utils";
import type { WorkflowRun } from "@/lib/types";

const actions = [
  {
    title: "Deploy Regional Hub",
    description: "Provision 14 resource groups (13 Foundry instances + APIM gateway) for a new regional hub.",
    href: "/deploy-hub",
    icon: Rocket,
    iconBg: "bg-blue-50",
    iconColor: "text-kpmg-blue",
    workflow: "deploy-hub.yml",
  },
  {
    title: "Provision Foundry Project",
    description: "Create an isolated project across any of the 13 Foundry tiers with Project Admin and Project User RBAC.",
    href: "/provision-project",
    icon: FolderPlus,
    iconBg: "bg-emerald-50",
    iconColor: "text-emerald-700",
    workflow: "provision-foundry-project.yml",
  },
  {
    title: "Deprovision Project",
    description: "Safely decommission a Foundry project — removes RBAC, deletes the project resource.",
    href: "/deprovision",
    icon: Trash2,
    iconBg: "bg-red-50",
    iconColor: "text-red-600",
    workflow: "deprovision-project.yml",
  },
  {
    title: "Drift Detection",
    description: "Run Bicep what-if against live infrastructure to surface IaC drift across all hub subscriptions.",
    href: "/drift-detection",
    icon: ShieldCheck,
    iconBg: "bg-amber-50",
    iconColor: "text-amber-600",
    workflow: "drift-detection.yml",
  },
  {
    title: "Workflow Run History",
    description: "Audit log of all GitHub Actions executions with real-time status and links to run logs.",
    href: "/runs",
    icon: History,
    iconBg: "bg-purple-50",
    iconColor: "text-purple-700",
    workflow: "All workflows",
  },
];

export default function DashboardPage() {
  const [runs, setRuns] = useState<WorkflowRun[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.listRuns(undefined, 5)
      .then((r) => setRuns(r.runs))
      .catch(() => setRuns([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* ── Hero banner ── */}
      <div className="relative overflow-hidden rounded-2xl bg-kpmg-blue px-8 py-8 text-white shadow-card-hover">
        {/* decorative gradient */}
        <div className="absolute inset-0 bg-gradient-to-br from-kpmg-mid-blue/50 to-transparent pointer-events-none" />
        <div className="relative flex items-start justify-between gap-6">
          <div className="max-w-xl">
            <p className="text-[10px] font-bold uppercase tracking-widest text-white/50 mb-1">
              KPMG · AI OS Platform
            </p>
            <h2 className="text-2xl font-bold leading-tight">Foundry Vending Platform</h2>
            <p className="mt-2 text-sm text-white/70 leading-relaxed">
              Centralised administration console for provisioning Microsoft Foundry projects
              across AMR, EMEA, and APAC hubs — with RBAC isolation, approved-model governance,
              and full IaC auditability.
            </p>
          </div>
          <div className="hidden lg:flex flex-col gap-3 shrink-0">
            {[
              { icon: Globe, label: "3 Regional Hubs", sub: "AMR · EMEA · APAC" },
              { icon: Layers, label: "14 Resource Groups", sub: "13 Foundry + 1 APIM per hub" },
              { icon: GitBranch, label: "GitHub Actions", sub: "IaC via Azure Bicep" },
            ].map(({ icon: Icon, label, sub }) => (
              <div key={label} className="flex items-center gap-2.5 rounded-xl bg-white/10 px-4 py-2">
                <Icon size={16} className="text-white/70 shrink-0" />
                <div>
                  <p className="text-xs font-semibold leading-tight">{label}</p>
                  <p className="text-[10px] text-white/50 leading-tight">{sub}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* ── Action cards ── */}
      <div>
        <p className="text-[10px] font-bold uppercase tracking-widest text-kpmg-gray-dark mb-3">
          Platform Actions
        </p>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {actions.map((a) => {
            const Icon = a.icon;
            return (
              <Link key={a.href} href={a.href} className="group">
                <Card className="h-full transition-all hover:shadow-card-hover hover:-translate-y-0.5">
                  <div className={`mb-4 inline-flex h-10 w-10 items-center justify-center rounded-xl ${a.iconBg}`}>
                    <Icon size={20} className={a.iconColor} />
                  </div>
                  <h4 className="font-bold text-kpmg-black group-hover:text-kpmg-blue transition-colors">
                    {a.title}
                  </h4>
                  <p className="mt-1.5 text-sm text-kpmg-gray-dark leading-relaxed">{a.description}</p>
                  <div className="mt-4 flex items-center justify-between">
                    <span className="text-[10px] font-mono text-kpmg-gray-dark">{a.workflow}</span>
                    <span className="flex items-center gap-1 text-xs font-semibold text-kpmg-blue">
                      Open <ArrowRight size={12} className="group-hover:translate-x-1 transition-transform" />
                    </span>
                  </div>
                </Card>
              </Link>
            );
          })}
        </div>
      </div>

      {/* ── Recent runs ── */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <p className="text-[10px] font-bold uppercase tracking-widest text-kpmg-gray-dark">
            Recent Workflow Runs
          </p>
          <Link href="/runs" className="flex items-center gap-1 text-xs font-semibold text-kpmg-blue hover:text-kpmg-mid-blue">
            View all <ArrowRight size={11} />
          </Link>
        </div>
        <Card>
          {loading ? (
            <div className="flex items-center gap-2 text-sm text-kpmg-gray-dark py-4">
              <Activity size={14} className="animate-pulse" />
              Loading recent runs…
            </div>
          ) : runs.length === 0 ? (
            <p className="text-sm text-kpmg-gray-dark py-4 text-center">
              No workflow runs found. Trigger an action above to get started.
            </p>
          ) : (
            <div className="divide-y divide-kpmg-gray-mid">
              {runs.map((run) => (
                <div key={run.id} className="flex items-center gap-4 py-3">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-kpmg-black truncate">
                      {run.display_title ?? run.name ?? `Run #${run.run_number}`}
                    </p>
                    <p className="text-xs text-kpmg-gray-dark mt-0.5">
                      #{run.run_number} · {timeAgo(run.created_at)}
                    </p>
                  </div>
                  <Badge value={run.status === "completed" ? run.conclusion : run.status} />
                  {run.html_url && (
                    <a
                      href={run.html_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xs text-kpmg-blue hover:text-kpmg-mid-blue font-medium shrink-0"
                    >
                      View →
                    </a>
                  )}
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>

      {/* ── Platform info strip ── */}
      <div className="rounded-xl border border-kpmg-gray-mid bg-white p-4 flex flex-wrap gap-8 text-sm">
        {[
          { label: "IaC", value: "Azure Bicep" },
          { label: "Policy Engine", value: "OPA + Azure Policy" },
          { label: "Auth", value: "OIDC (FWIC)" },
          { label: "Model Governance", value: "Hub-approved list + RBAC notActions" },
          { label: "Isolation", value: "Project-scoped RBAC, single subscription" },
        ].map(({ label, value }) => (
          <div key={label}>
            <p className="text-[9px] font-bold uppercase tracking-widest text-kpmg-gray-dark">{label}</p>
            <p className="font-semibold text-kpmg-black">{value}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
