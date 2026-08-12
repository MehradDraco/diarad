import { useQuery } from "@tanstack/react-query";
import { Activity, Cpu, ShieldCheck, Terminal } from "lucide-react";

import { getHostStatus } from "@/lib/host.functions";
import { faNum } from "@/lib/format";
import { cn } from "@/lib/utils";

const STABILITY_LABEL: Record<string, string> = {
  excellent: "پایدار — عالی",
  stable: "پایدار",
  degraded: "پایدار با تاخیر",
  unknown: "در حال اندازه‌گیری",
};

export function HostStatusCard({ className }: { className?: string }) {
  const { data, isLoading } = useQuery({
    queryKey: ["host-status"],
    queryFn: () => getHostStatus(),
    refetchInterval: 30_000,
  });

  return (
    <div className={cn("panel p-5", className)}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2 text-[13px] font-medium">
          <Activity className="size-4 text-brand" />
          وضعیت زنده دیانا ابر
        </div>
        <span className="flex items-center gap-2 text-[12px] text-muted-foreground">
          <span
            className={cn(
              "live-dot size-2 rounded-full",
              data?.online ? "bg-success" : isLoading ? "bg-warn" : "bg-destructive",
            )}
          />
          {isLoading ? "در حال بررسی" : data?.online ? "آنلاین" : "پاسخ نمی‌دهد"}
        </span>
      </div>

      <div className="mt-4 grid gap-3 sm:grid-cols-3">
        <Metric
          icon={<Terminal className="size-3.5" />}
          label="پینگ (میانگین)"
          value={data?.latencyMs != null ? `${faNum(data.latencyMs)} ms` : "—"}
        />
        <Metric
          icon={<Cpu className="size-3.5" />}
          label="سیستم‌عامل"
          value={data?.os ?? "Ubuntu 22.04 LTS"}
          mono
        />
        <Metric
          icon={<ShieldCheck className="size-3.5" />}
          label="پایداری"
          value={STABILITY_LABEL[data?.stability ?? "unknown"]!}
        />
      </div>

      <div className="mt-4 flex flex-wrap items-center gap-2 border-t border-hairline pt-4">
        <span className="ltr-mono text-[12px] text-muted-foreground">{data?.host ?? "194.60.231.49"}</span>
        {(data?.probes ?? []).map((p) => (
          <span
            key={p.port}
            className={cn(
              "ltr-mono rounded-md border border-hairline px-2 py-1 text-[11px]",
              p.open ? "text-success" : "text-muted-foreground",
            )}
          >
            {p.label}:{p.port} {p.latencyMs != null ? `${p.latencyMs}ms` : "—"}
          </span>
        ))}
      </div>
    </div>
  );
}

function Metric({
  icon,
  label,
  value,
  mono,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="rounded-md border border-hairline bg-surface/50 p-3">
      <div className="flex items-center gap-1.5 text-[11px] text-muted-foreground">
        {icon}
        {label}
      </div>
      <div className={cn("mt-1.5 text-sm font-medium", mono && "ltr-mono text-[13px]")}>{value}</div>
    </div>
  );
}
