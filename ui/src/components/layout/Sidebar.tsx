"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Rocket,
  FolderPlus,
  Trash2,
  ShieldCheck,
  History,
  ChevronRight,
} from "lucide-react";

const nav = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/deploy-hub", label: "Deploy Hub", icon: Rocket },
  { href: "/vend-project", label: "Vend Project", icon: FolderPlus },
  { href: "/deprovision", label: "Deprovision", icon: Trash2 },
  { href: "/drift-detection", label: "Drift Detection", icon: ShieldCheck },
  { href: "/runs", label: "Workflow Runs", icon: History },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex h-full w-64 flex-col bg-kpmg-blue text-white">
      {/* Brand */}
      <div className="flex items-center gap-3 px-5 py-5 border-b border-white/10">
        {/* KPMG wordmark */}
        <div className="flex h-8 w-8 items-center justify-center rounded bg-white">
          <span className="text-[11px] font-black text-kpmg-blue tracking-tighter">KPMG</span>
        </div>
        <div>
          <p className="text-xs font-bold leading-tight">AI OS</p>
          <p className="text-[10px] text-white/50 leading-tight">Foundry Vending</p>
        </div>
      </div>

      {/* Region badges */}
      <div className="px-5 pt-4 pb-2">
        <p className="text-[9px] font-bold uppercase tracking-widest text-white/40 mb-2">Active Hubs</p>
        <div className="flex gap-1.5">
          {["AMR", "EMEA", "APAC"].map((r) => (
            <span key={r} className="rounded bg-white/10 px-2 py-0.5 text-[10px] font-bold">
              {r}
            </span>
          ))}
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-3 pt-3 pb-4 space-y-0.5">
        <p className="px-2 py-1 text-[9px] font-bold uppercase tracking-widest text-white/30 mb-1">
          Platform Actions
        </p>
        {nav.map(({ href, label, icon: Icon }) => {
          const active = pathname === href;
          return (
            <Link
              key={href}
              href={href}
              className={`group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-all ${
                active
                  ? "bg-white/15 text-white"
                  : "text-white/60 hover:bg-white/10 hover:text-white"
              }`}
            >
              <Icon size={16} className={active ? "text-white" : "text-white/50 group-hover:text-white"} />
              <span className="flex-1">{label}</span>
              {active && <ChevronRight size={12} className="opacity-60" />}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="border-t border-white/10 px-5 py-4">
        <p className="text-[9px] text-white/30 font-semibold uppercase tracking-widest">
          © 2025 KPMG International
        </p>
      </div>
    </aside>
  );
}
