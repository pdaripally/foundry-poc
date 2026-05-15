import { cn } from "@/lib/utils";

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export function Card({ children, className }: CardProps) {
  return (
    <div className={cn("rounded-xl border border-kpmg-gray-mid bg-white p-5 shadow-card", className)}>
      {children}
    </div>
  );
}

export function CardHeader({ children }: { children: React.ReactNode }) {
  return <div className="mb-4 pb-3 border-b border-kpmg-gray-mid">{children}</div>;
}

export function CardTitle({ children }: { children: React.ReactNode }) {
  return <h3 className="text-sm font-bold uppercase tracking-wide text-kpmg-gray-dark">{children}</h3>;
}
