#!/bin/bash
# Pontic — Charts + Polish + Deploy prep
# Run from inside frontend/ folder

# ── components/charts/TimeSeriesChart.tsx ──────────────────────────────────
mkdir -p components/charts

cat > components/charts/TimeSeriesChart.tsx << 'EOF'
"use client";

import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis,
  CartesianGrid, Tooltip, ReferenceLine
} from "recharts";
import { fmt, fmtDate } from "@/lib/format";

interface DataPoint {
  date: string;
  value: number;
  mom_pct?: number | null;
  yoy_pct?: number | null;
  zscore?:  number | null;
}

interface Props {
  data:      DataPoint[];
  unit?:     string;
  color?:    string;
  height?:   number;
  showZscore?: boolean;
}

function CustomTooltip({ active, payload, label, unit }: any) {
  if (!active || !payload?.length) return null;
  const d = payload[0]?.payload;
  return (
    <div className="bg-zinc-900 border border-zinc-700 rounded-lg p-3 text-xs shadow-xl">
      <p className="text-zinc-400 mb-2 font-mono">{label}</p>
      <p className="text-zinc-100 font-semibold font-mono">
        {fmt(d.value)} <span className="text-zinc-500">{unit}</span>
      </p>
      {d.mom_pct != null && (
        <p className={`mt-1 font-mono ${d.mom_pct >= 0 ? "text-emerald-400" : "text-red-400"}`}>
          MoM {d.mom_pct >= 0 ? "+" : ""}{fmt(d.mom_pct)}%
        </p>
      )}
      {d.yoy_pct != null && (
        <p className={`font-mono ${d.yoy_pct >= 0 ? "text-emerald-400" : "text-red-400"}`}>
          YoY {d.yoy_pct >= 0 ? "+" : ""}{fmt(d.yoy_pct)}%
        </p>
      )}
      {d.zscore != null && (
        <p className="text-zinc-400 font-mono mt-1">Z {fmt(d.zscore)}</p>
      )}
    </div>
  );
}

export default function TimeSeriesChart({
  data, unit = "", color = "#3b82f6", height = 220, showZscore = false
}: Props) {
  const sorted = [...data].sort((a, b) =>
    new Date(a.date).getTime() - new Date(b.date).getTime()
  ).slice(-120); // last 120 points

  const values  = sorted.map(d => d.value).filter(Boolean);
  const min     = Math.min(...values);
  const max     = Math.max(...values);
  const padding = (max - min) * 0.05;

  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={sorted} margin={{ top: 4, right: 4, left: 0, bottom: 0 }}>
        <defs>
          <linearGradient id={`grad-${color.replace("#","")}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%"  stopColor={color} stopOpacity={0.2} />
            <stop offset="95%" stopColor={color} stopOpacity={0}   />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
        <XAxis
          dataKey="date"
          tickFormatter={d => {
            const date = new Date(d);
            return date.toLocaleDateString("en-GB", { month: "short", year: "2-digit" });
          }}
          tick={{ fill: "#52525b", fontSize: 11, fontFamily: "monospace" }}
          tickLine={false}
          axisLine={false}
          interval="preserveStartEnd"
          minTickGap={60}
        />
        <YAxis
          domain={[min - padding, max + padding]}
          tick={{ fill: "#52525b", fontSize: 11, fontFamily: "monospace" }}
          tickLine={false}
          axisLine={false}
          tickFormatter={v => fmt(v, 1)}
          width={52}
        />
        <Tooltip content={<CustomTooltip unit={unit} />} />
        <Area
          type="monotone"
          dataKey="value"
          stroke={color}
          strokeWidth={1.5}
          fill={`url(#grad-${color.replace("#","")})`}
          dot={false}
          activeDot={{ r: 4, fill: color, stroke: "#09090b", strokeWidth: 2 }}
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}
EOF

# ── components/charts/MiniSparkline.tsx ────────────────────────────────────
cat > components/charts/MiniSparkline.tsx << 'EOF'
"use client";

import { LineChart, Line, ResponsiveContainer, Tooltip } from "recharts";

interface Props {
  data:   { value: number }[];
  color?: string;
  height?: number;
}

export default function MiniSparkline({
  data, color = "#3b82f6", height = 40
}: Props) {
  if (!data?.length) return null;
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data}>
        <Line
          type="monotone"
          dataKey="value"
          stroke={color}
          strokeWidth={1.5}
          dot={false}
          isAnimationActive={false}
        />
        <Tooltip
          content={() => null}
          cursor={{ stroke: "#52525b", strokeWidth: 1 }}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
EOF

# ── app/indicators/[key]/page.tsx — Indicator detail page ─────────────────
mkdir -p app/indicators/\[key\]
cat > "app/indicators/[key]/page.tsx" << 'EOF'
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
EOF

# ── Make indicator rows clickable ──────────────────────────────────────────
cat > components/cards/SignalRow.tsx << 'EOF'
"use client";

import Link from "next/link";
import { Indicator } from "@/lib/api";
import {
  fmt, fmtPct, fmtDate,
  directionColor, directionIcon, zscoreColor
} from "@/lib/format";
import { clsx } from "clsx";

export default function SignalRow({ ind }: { ind: Indicator }) {
  return (
    <tr className="border-b border-zinc-800/50 hover:bg-zinc-800/30 transition-colors cursor-pointer group">
      <td className="py-3 px-4">
        <Link href={`/indicators/${ind.series_key}`} className="block">
          <p className="text-sm font-medium text-zinc-100 group-hover:text-blue-400 transition-colors">
            {ind.indicator_name}
          </p>
          <p className="text-xs text-zinc-500 font-mono">{ind.series_key}</p>
        </Link>
      </td>
      <td className="py-3 px-4 text-right font-mono text-sm text-zinc-200">
        {fmt(ind.latest_value)}{" "}
        <span className="text-zinc-600 text-xs">{ind.unit}</span>
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
EOF

# ── components/ui/LoadingSkeleton.tsx ──────────────────────────────────────
cat > components/ui/LoadingSkeleton.tsx << 'EOF'
export function SkeletonCard() {
  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5 animate-pulse">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-zinc-800 rounded-full" />
          <div>
            <div className="w-24 h-3 bg-zinc-800 rounded mb-1" />
            <div className="w-12 h-2 bg-zinc-800 rounded" />
          </div>
        </div>
        <div className="w-20 h-5 bg-zinc-800 rounded-full" />
      </div>
      <div className="grid grid-cols-2 gap-3">
        {[...Array(6)].map((_, i) => (
          <div key={i} className="bg-zinc-800/50 rounded-lg p-2.5">
            <div className="w-16 h-2 bg-zinc-700 rounded mb-1.5" />
            <div className="w-12 h-3 bg-zinc-700 rounded" />
          </div>
        ))}
      </div>
    </div>
  );
}

export function SkeletonTable({ rows = 8 }: { rows?: number }) {
  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
      <div className="border-b border-zinc-800 px-4 py-3 flex gap-4">
        {[40, 20, 15, 15, 10].map((w, i) => (
          <div key={i} className={`h-3 bg-zinc-800 rounded`}
            style={{ width: `${w}%` }} />
        ))}
      </div>
      {[...Array(rows)].map((_, i) => (
        <div key={i} className="border-b border-zinc-800/50 px-4 py-3 flex gap-4 animate-pulse">
          {[40, 20, 15, 15, 10].map((w, j) => (
            <div key={j} className="h-3 bg-zinc-800 rounded"
              style={{ width: `${w}%` }} />
          ))}
        </div>
      ))}
    </div>
  );
}

export function SkeletonRegime() {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900 p-6 animate-pulse">
      <div className="w-32 h-3 bg-zinc-800 rounded mb-3" />
      <div className="w-48 h-8 bg-zinc-800 rounded mb-4" />
      <div className="w-full h-4 bg-zinc-800 rounded" />
    </div>
  );
}
EOF

# ── app/loading.tsx — global loading state ─────────────────────────────────
cat > app/loading.tsx << 'EOF'
import { SkeletonRegime, SkeletonTable } from "@/components/ui/LoadingSkeleton";

export default function Loading() {
  return (
    <div className="space-y-8">
      <div>
        <div className="w-48 h-7 bg-zinc-800 rounded animate-pulse mb-2" />
        <div className="w-80 h-4 bg-zinc-800 rounded animate-pulse" />
      </div>
      <SkeletonRegime />
      <div className="grid grid-cols-2 gap-3">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="bg-zinc-900 border border-zinc-800 rounded-lg p-4 animate-pulse">
            <div className="w-24 h-4 bg-zinc-800 rounded mb-1" />
            <div className="w-32 h-3 bg-zinc-800 rounded" />
          </div>
        ))}
      </div>
      <SkeletonTable />
    </div>
  );
}
EOF

echo "✅ Charts + polish written"
