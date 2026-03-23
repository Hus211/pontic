// Pontic — Indicator Detail Page

import { api } from "@/lib/api";
import TimeSeriesChart from "@/components/charts/TimeSeriesChart";
import { fmt, fmtPct, fmtDate, zscoreColor, directionColor, directionIcon } from "@/lib/format";
import { clsx } from "clsx";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

export const revalidate = 180;

const CHART_COLORS: Record<string, string> = {
  GDP:             "#10b981",
  CPI:             "#f59e0b",
  FED_FUNDS:       "#3b82f6",
  UNEMPLOYMENT:    "#ef4444",
  TREASURY_10Y:    "#8b5cf6",
  TREASURY_2Y:     "#a78bfa",
  M2:              "#06b6d4",
  PCE:             "#f97316",
  RETAIL_SALES:    "#84cc16",
  INDUSTRIAL_PROD: "#6366f1",
  HOUSING_STARTS:  "#ec4899",
  CONSUMER_SENT:   "#14b8a6",
};

export default async function IndicatorPage({
  params
}: {
  params: Promise<{ key: string }>
}) {
  const { key } = await params;
  const data = await api.indicator(key.toUpperCase(), 120);
  const latest = data.data[0];
  const color  = CHART_COLORS[key.toUpperCase()] || "#3b82f6";

  return (
    <div className="space-y-6">
      {/* Back link */}
      <Link href="/indicators"
        className="inline-flex items-center gap-1.5 text-sm text-zinc-500 hover:text-zinc-300 transition-colors">
        <ArrowLeft size={14} /> All Indicators
      </Link>

      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs text-zinc-500 font-mono mb-1">{data.series_key}</p>
          <h1 className="text-2xl font-bold text-zinc-100">{data.indicator_name}</h1>
          <p className="text-sm text-zinc-500 mt-1">
            {data.unit} · {data.country_code} · {data.count} observations
          </p>
        </div>
        {latest && (
          <div className="text-right">
            <p className="text-3xl font-bold font-mono text-zinc-100">
              {fmt(latest.latest_value ?? latest.value)}
            </p>
            <p className="text-xs text-zinc-500 mt-1">{fmtDate(latest.latest_date ?? latest.date)}</p>
          </div>
        )}
      </div>

      {/* Stats row */}
      {latest && (
        <div className="grid grid-cols-4 gap-3">
          {[
            { label: "MoM Change",  value: fmtPct(latest.mom_pct),
              color: directionColor(latest.mom_direction) },
            { label: "YoY Change",  value: fmtPct(latest.yoy_pct),
              color: latest.yoy_pct != null && latest.yoy_pct >= 0
                ? "text-emerald-400" : "text-red-400" },
            { label: "Z-Score",     value: fmt(latest.zscore),
              color: zscoreColor(latest.zscore) },
            { label: "Signal",      value: latest.zscore_label,
              color: latest.zscore_label === "EXTREME" ? "text-red-400"
                : latest.zscore_label === "ELEVATED" ? "text-amber-400"
                : "text-zinc-400" },
          ].map(({ label, value, color: c }) => (
            <div key={label} className="bg-zinc-900 border border-zinc-800 rounded-xl p-4">
              <p className="text-xs text-zinc-500 mb-1">{label}</p>
              <p className={clsx("text-lg font-bold font-mono", c)}>{value}</p>
            </div>
          ))}
        </div>
      )}

      {/* Chart */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
        <h2 className="text-sm font-semibold text-zinc-300 mb-4">
          Historical Series
          <span className="ml-2 text-xs text-zinc-600 font-normal">last 120 observations</span>
        </h2>
        <TimeSeriesChart
          data={data.data.map(d => ({
            date:    d.date ?? d.latest_date,
            value:   d.value ?? d.latest_value,
            mom_pct: d.mom_pct,
            yoy_pct: d.yoy_pct,
            zscore:  d.zscore,
          }))}
          unit={data.unit}
          color={color}
          height={280}
        />
      </div>

      {/* Data table */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
        <div className="px-6 py-4 border-b border-zinc-800">
          <h2 className="text-sm font-semibold text-zinc-300">Raw Data</h2>
        </div>
        <div className="overflow-y-auto max-h-80">
          <table className="w-full">
            <thead className="sticky top-0 bg-zinc-900">
              <tr className="border-b border-zinc-800">
                {["Date", "Value", "MoM %", "YoY %", "Z-Score"].map(h => (
                  <th key={h} className="py-2 px-4 text-left text-xs font-medium text-zinc-500 uppercase">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.data.map((row, i) => (
                <tr key={i} className="border-b border-zinc-800/50 hover:bg-zinc-800/20">
                  <td className="py-2 px-4 text-xs font-mono text-zinc-400">
                    {fmtDate(row.date ?? row.latest_date)}
                  </td>
                  <td className="py-2 px-4 text-xs font-mono text-zinc-200">
                    {fmt(row.value ?? row.latest_value)}
                  </td>
                  <td className={clsx("py-2 px-4 text-xs font-mono",
                    directionColor(row.mom_direction))}>
                    {fmtPct(row.mom_pct)}
                  </td>
                  <td className="py-2 px-4 text-xs font-mono text-zinc-300">
                    {fmtPct(row.yoy_pct)}
                  </td>
                  <td className={clsx("py-2 px-4 text-xs font-mono font-semibold",
                    zscoreColor(row.zscore))}>
                    {row.zscore != null ? fmt(row.zscore) : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
