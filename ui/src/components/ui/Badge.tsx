type BadgeVariant = "success" | "failure" | "in_progress" | "queued" | "waiting" | "neutral";

const variantMap: Record<string, BadgeVariant> = {
  success: "success",
  failure: "failure",
  in_progress: "in_progress",
  queued: "queued",
  waiting: "waiting",
  completed: "neutral",
  cancelled: "neutral",
  skipped: "neutral",
  timed_out: "failure",
};

const styles: Record<BadgeVariant, string> = {
  success: "bg-emerald-100 text-emerald-700 border-emerald-200",
  failure: "bg-red-100 text-red-700 border-red-200",
  in_progress: "bg-blue-100 text-blue-700 border-blue-200",
  queued: "bg-kpmg-gray text-kpmg-gray-dark border-kpmg-gray-mid",
  waiting: "bg-amber-100 text-amber-700 border-amber-200",
  neutral: "bg-kpmg-gray text-kpmg-gray-dark border-kpmg-gray-mid",
};

const labels: Partial<Record<string, string>> = {
  in_progress: "In Progress",
  timed_out: "Timed Out",
};

interface BadgeProps {
  value: string | null | undefined;
  type?: "status" | "conclusion";
}

export function Badge({ value, type = "status" }: BadgeProps) {
  if (!value) return <span className="text-xs text-kpmg-gray-dark">—</span>;
  const key = value.toLowerCase();
  const variant = variantMap[key] ?? "neutral";
  const label = labels[key] ?? value.replace(/_/g, " ");
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-[11px] font-semibold capitalize ${styles[variant]}`}
    >
      {type === "status" && value === "in_progress" && (
        <span className="mr-1.5 h-1.5 w-1.5 rounded-full bg-blue-500 animate-pulse" />
      )}
      {label}
    </span>
  );
}
