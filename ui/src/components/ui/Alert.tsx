"use client";

import { CheckCircle2, XCircle, AlertTriangle, X } from "lucide-react";

interface AlertProps {
  variant: "success" | "error" | "warning";
  title: string;
  message?: string;
  onDismiss?: () => void;
}

const styles = {
  success: {
    wrapper: "bg-emerald-50 border-emerald-200 text-emerald-800",
    icon: <CheckCircle2 size={16} className="shrink-0 text-emerald-600 mt-0.5" />,
  },
  error: {
    wrapper: "bg-red-50 border-red-200 text-red-800",
    icon: <XCircle size={16} className="shrink-0 text-red-600 mt-0.5" />,
  },
  warning: {
    wrapper: "bg-amber-50 border-amber-200 text-amber-800",
    icon: <AlertTriangle size={16} className="shrink-0 text-amber-600 mt-0.5" />,
  },
};

export function Alert({ variant, title, message, onDismiss }: AlertProps) {
  const s = styles[variant];
  return (
    <div className={`flex gap-3 rounded-lg border p-3 text-sm ${s.wrapper}`}>
      {s.icon}
      <div className="flex-1 min-w-0">
        <p className="font-semibold">{title}</p>
        {message && <p className="mt-0.5 text-xs opacity-80 break-words">{message}</p>}
      </div>
      {onDismiss && (
        <button onClick={onDismiss} className="shrink-0 opacity-60 hover:opacity-100 transition-opacity">
          <X size={14} />
        </button>
      )}
    </div>
  );
}
