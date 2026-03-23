// Pontic — Macro Regime Card

import { RegimeResponse } from "@/lib/api";
import { REGIME_COLORS, REGIME_BG, fmt, fmtPct } from "@/lib/format";
import { clsx } from "clsx";

export default function RegimeCard({ regime }: { regime: RegimeResponse }) {
  return (
    <div className={clsx(
      "rounded-xl border p-6",
      REGIME_BG[regime.regime] || "bg-zinc-900 border-zinc-700"
    )}>
      <div className="flex items-start justify-between mb-4">
        <div>
          <p className="text-xs text-zinc-500 uppercase tracking-widest mb-1">
            Current Macro Regime
          </p>
          <h2 className={clsx(
            "text-3xl font-bold tracking-tight",
            REGIME_COLORS[regime.regime]
          )}>
            {regime.regime}
          </h2>
        </div>
        <div className="text-right">
          <div className="flex gap-4 text-sm">
            <div>
              <p className="text-zinc-500 text-xs mb-0.5">GDP YoY</p>
              <p className={clsx("font-mono font-semibold",
                regime.growth_up ? "text-emerald-400" : "text-red-400"
              )}>
                {fmtPct(regime.gdp_yoy_pct)}
              </p>
            </div>
            <div>
              <p className="text-zinc-500 text-xs mb-0.5">CPI YoY</p>
              <p className={clsx("font-mono font-semibold",
                !regime.inflation_up ? "text-emerald-400" : "text-red-400"
              )}>
                {fmtPct(regime.cpi_yoy_pct)}
              </p>
            </div>
          </div>
        </div>
      </div>
      <p className="text-sm text-zinc-300 leading-relaxed">
        {regime.description}
      </p>
    </div>
  );
}
