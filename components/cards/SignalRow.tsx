// Pontic — Signal Table Row

import { Indicator } from "@/lib/api";
import {
  fmt, fmtPct, fmtDate,
  directionColor, directionIcon, zscoreColor
} from "@/lib/format";
import { clsx } from "clsx";

export default function SignalRow({ ind }: { ind: Indicator }) {
  return (
    <tr className="border-b border-zinc-800/50 hover:bg-zinc-800/20 transition-colors">
      <td className="py-3 px-4">
        <p className="text-sm font-medium text-zinc-100">{ind.indicator_name}</p>
        <p className="text-xs text-zinc-500 font-mono">{ind.series_key}</p>
      </td>
      <td className="py-3 px-4 text-right font-mono text-sm text-zinc-200">
        {fmt(ind.latest_value)} <span className="text-zinc-600 text-xs">{ind.unit}</span>
      </td>
      <td className={clsx("py-3 px-4 text-right font-mono text-sm",
        directionColor(ind.mom_direction))}>
        {directionIcon(ind.mom_direction)} {fmtPct(ind.mom_pct)}
      </td>
      <td className="py-3 px-4 text-right font-mono text-sm text-zinc-300">
        {fmtPct(ind.yoy_pct)}
      </td>
      <td className={clsx("py-3 px-4 text-right font-mono text-sm font-semibold",
        zscoreColor(ind.zscore))}>
        {ind.zscore != null ? fmt(ind.zscore) : "—"}
      </td>
      <td className="py-3 px-4 text-right">
        <span className={clsx(
          "text-xs px-2 py-0.5 rounded-full font-medium",
          ind.zscore_label === "EXTREME"  && "bg-red-950 text-red-400",
          ind.zscore_label === "ELEVATED" && "bg-amber-950 text-amber-400",
          ind.zscore_label === "NORMAL"   && "bg-zinc-800 text-zinc-400",
        )}>
          {ind.zscore_label}
        </span>
      </td>
      <td className="py-3 px-4 text-right text-xs text-zinc-600 font-mono">
        {fmtDate(ind.latest_date)}
      </td>
    </tr>
  );
}
