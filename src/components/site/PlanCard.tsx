import { Link } from "@tanstack/react-router";
import { Lock } from "lucide-react";

import { toman, faNum } from "@/lib/format";
import { cn } from "@/lib/utils";

export type PlanRow = {
  id: string;
  name: string;
  ram: string;
  cpu: string;
  disk: string;
  bandwidth_gb: number;
  price_toman: number;
  is_popular: boolean;
  is_locked: boolean;
  lock_note: string;
  kind: string;
};

export function PlanCard({ plan }: { plan: PlanRow }) {
  const locked = plan.is_locked;
  return (
    <div
      className={cn(
        "panel relative flex flex-col p-5 transition-colors",
        plan.is_popular && !locked ? "border-brand/40" : "hover:border-foreground/20",
        locked && "opacity-70",
      )}
    >
      {plan.is_popular && !locked && (
        <span className="absolute -top-2.5 right-5 rounded-full bg-brand px-2 py-0.5 text-[10px] font-medium text-brand-foreground">
          محبوب
        </span>
      )}
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold">{plan.name}</span>
        {locked && <Lock className="size-3.5 text-muted-foreground" />}
      </div>
      <div className="mt-4 space-y-1.5 text-[12px] text-muted-foreground">
        <Row label="رم" value={plan.ram} />
        <Row label="CPU" value={plan.cpu} />
        <Row label="SSD" value={plan.disk} />
        <Row label="ترافیک" value={`${faNum(plan.bandwidth_gb)}GB`} />
      </div>
      <div className="mt-5 flex items-end gap-1">
        <span className="ltr-mono text-xl font-semibold">{toman(plan.price_toman)}</span>
        <span className="pb-0.5 text-[11px] text-muted-foreground">تومان / ماه</span>
      </div>
      {locked ? (
        <div className="mt-4 rounded-md border border-hairline bg-surface/60 px-3 py-2 text-center text-[12px] text-muted-foreground">
          {plan.lock_note || "فعلاً فروش نمی‌رود"}
        </div>
      ) : (
        <Link
          to="/panel"
          className={cn(
            "mt-4 inline-flex h-9 items-center justify-center rounded-md text-[13px] font-medium transition-opacity hover:opacity-90",
            plan.is_popular
              ? "bg-brand text-brand-foreground"
              : "border border-hairline text-foreground hover:border-foreground/25",
          )}
        >
          سفارش این پلن
        </Link>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between border-b border-hairline/60 pb-1.5 last:border-0">
      <span>{label}</span>
      <span className="ltr-mono text-foreground">{value || "—"}</span>
    </div>
  );
}
