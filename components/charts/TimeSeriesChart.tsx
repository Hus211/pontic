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
