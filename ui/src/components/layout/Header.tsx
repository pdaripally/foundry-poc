"use client";

import { usePathname } from "next/navigation";
import { Activity } from "lucide-react";

const titles: Record<string, { title: string; subtitle: string }> = {
  "/": { title: "Dashboard", subtitle: "AI OS Foundry Vending Platform" },
  "/deploy-hub": { title: "Deploy Regional Hub", subtitle: "Provision all 3 subscriptions for an AMR, EMEA, or APAC hub" },
  "/vend-project": { title: "Vend Foundry Project", subtitle: "Create a new isolated project with RBAC governance" },
  "/deprovision": { title: "Deprovision Project", subtitle: "Safely decommission a Foundry project and its RBAC assignments" },
  "/drift-detection": { title: "Drift Detection", subtitle: "Run IaC what-if analysis across hub subscriptions" },
  "/runs": { title: "Workflow Run History", subtitle: "Real-time status of all GitHub Actions workflow executions" },
};

export function Header() {
  const pathname = usePathname();
  const meta = titles[pathname] ?? { title: pathname, subtitle: "" };

  return (
    <header className="flex h-14 items-center justify-between border-b border-kpmg-gray-mid bg-white px-6 shadow-sm">
      <div>
        <h1 className="text-base font-bold text-kpmg-black leading-tight">{meta.title}</h1>
        {meta.subtitle && (
          <p className="text-xs text-kpmg-gray-dark leading-tight">{meta.subtitle}</p>
        )}
      </div>
      <div className="flex items-center gap-2 text-xs text-kpmg-gray-dark">
        <Activity size={13} className="text-emerald-500" />
        <span>GitHub Actions connected</span>
      </div>
    </header>
  );
}
