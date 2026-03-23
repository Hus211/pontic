// Pontic — Formatting utilities

export function fmt(value: number | null | undefined, decimals = 2): string {
  if (value == null) return "—";
  return value.toFixed(decimals);
}

export function fmtPct(value: number | null | undefined, decimals = 2): string {
  if (value == null) return "—";
  const sign = value > 0 ? "+" : "";
  return `${sign}${value.toFixed(decimals)}%`;
}

export function fmtLarge(value: number | null | undefined): string {
  if (value == null) return "—";
  if (Math.abs(value) >= 1e12) return `$${(value / 1e12).toFixed(1)}T`;
  if (Math.abs(value) >= 1e9)  return `$${(value / 1e9).toFixed(1)}B`;
  if (Math.abs(value) >= 1e6)  return `$${(value / 1e6).toFixed(1)}M`;
  return value.toLocaleString();
}

export function fmtDate(date: string | null | undefined): string {
  if (!date) return "—";
  return new Date(date).toLocaleDateString("en-GB", {
    month: "short", year: "numeric"
  });
}

export const REGIME_COLORS: Record<string, string> = {
  GOLDILOCKS:  "text-emerald-400",
  REFLATION:   "text-amber-400",
  STAGFLATION: "text-red-400",
  DEFLATION:   "text-blue-400",
  UNKNOWN:     "text-slate-400",
};

export const REGIME_BG: Record<string, string> = {
  GOLDILOCKS:  "bg-emerald-950 border-emerald-800",
  REFLATION:   "bg-amber-950 border-amber-800",
  STAGFLATION: "bg-red-950 border-red-800",
  DEFLATION:   "bg-blue-950 border-blue-800",
  UNKNOWN:     "bg-slate-900 border-slate-700",
};

export const GROWTH_COLORS: Record<string, string> = {
  EXPANDING:   "text-emerald-400",
  STABLE:      "text-blue-400",
  SLOWING:     "text-amber-400",
  CONTRACTING: "text-red-400",
};

export const TREND_COLORS: Record<string, string> = {
  STRONG_UP:   "text-emerald-400",
  UP:          "text-emerald-300",
  DOWN:        "text-red-300",
  STRONG_DOWN: "text-red-400",
};

export function zscoreColor(z: number | null): string {
  if (z == null) return "text-slate-400";
  const abs = Math.abs(z);
  if (abs > 2)  return z > 0 ? "text-red-400"    : "text-blue-400";
  if (abs > 1)  return z > 0 ? "text-amber-400"  : "text-sky-400";
  return "text-slate-300";
}

export function directionIcon(dir: string | null): string {
  if (dir === "UP")   return "↑";
  if (dir === "DOWN") return "↓";
  return "→";
}

export function directionColor(dir: string | null): string {
  if (dir === "UP")   return "text-emerald-400";
  if (dir === "DOWN") return "text-red-400";
  return "text-slate-400";
}
