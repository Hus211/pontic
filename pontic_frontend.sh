#!/bin/bash
# Pontic — Frontend: API client, types, layout, dashboard
# Run from inside frontend/ folder

# ── lib/api.ts ─────────────────────────────────────────────────────────────
mkdir -p lib hooks types components/charts components/cards components/layout

cat > lib/api.ts << 'EOF'
// Pontic — API Client

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

async function fetcher<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    next: { revalidate: 180 }, // 3 min cache
  });
  if (!res.ok) throw new Error(`API error: ${res.status} ${path}`);
  return res.json();
}

export const api = {
  regime:      () => fetcher<RegimeResponse>("/regime/current"),
  indicators:  (source?: string) =>
    fetcher<IndicatorsResponse>(`/indicators/${source ? `?source=${source}` : ""}`),
  indicator:   (key: string, limit = 120) =>
    fetcher<IndicatorDetail>(`/indicators/${key}?limit=${limit}`),
  countries:   () => fetcher<CountriesResponse>("/countries/"),
  country:     (code: string) => fetcher<Country>(`/countries/${code}`),
  market:      () => fetcher<MarketResponse>("/signals/market"),
  extremes:    (threshold = 1.5) =>
    fetcher<ExtremesResponse>(`/signals/extremes?threshold=${threshold}`),
};

// ── Types ──────────────────────────────────────────────────────────────────
export interface Indicator {
  source: string;
  series_key: string;
  indicator_name: string;
  unit: string;
  frequency: string;
  country_code: string;
  latest_date: string;
  latest_value: number;
  mom_pct: number | null;
  yoy_pct: number | null;
  zscore: number | null;
  mom_direction: "UP" | "DOWN" | "FLAT";
  zscore_label: "NORMAL" | "ELEVATED" | "EXTREME";
}

export interface IndicatorsResponse {
  count: number;
  indicators: Indicator[];
}

export interface IndicatorDetail {
  series_key: string;
  indicator_name: string;
  unit: string;
  country_code: string;
  count: number;
  data: (Indicator & { date: string; value: number })[];
}

export interface RegimeResponse {
  regime: "GOLDILOCKS" | "REFLATION" | "STAGFLATION" | "DEFLATION" | "UNKNOWN";
  description: string;
  gdp_yoy_pct: number;
  cpi_yoy_pct: number;
  growth_up: boolean;
  inflation_up: boolean;
  supporting_signals: Indicator[];
}

export interface Country {
  country_code: string;
  country_name: string;
  latest_date: string;
  gdp_trillions_usd: number | null;
  cpi_inflation_pct: number | null;
  debt_to_gdp_pct: number | null;
  unemployment_pct: number | null;
  cli_index: number | null;
  growth_signal: "EXPANDING" | "STABLE" | "SLOWING" | "CONTRACTING";
}

export interface CountriesResponse {
  count: number;
  countries: Country[];
}

export interface MarketSignal {
  series_key: string;
  ticker: string;
  asset_name: string;
  category: string;
  latest_date: string;
  latest_price: number;
  sma_20: number;
  sma_50: number;
  return_1m_pct: number | null;
  return_3m_pct: number | null;
  above_sma20: boolean;
  trend_signal: "STRONG_UP" | "UP" | "DOWN" | "STRONG_DOWN";
}

export interface MarketResponse {
  count: number;
  signals: MarketSignal[];
}

export interface ExtremesResponse {
  threshold: number;
  count: number;
  extremes: Indicator[];
}
EOF

# ── lib/utils.ts (extend existing) ────────────────────────────────────────
cat > lib/format.ts << 'EOF'
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
EOF

# ── app/globals.css — dark theme override ─────────────────────────────────
cat > app/globals.css << 'EOF'
@import "tailwindcss";
@import "tw-animate-css";

@custom-variant dark (&:is(.dark *));

:root {
  --background: #09090b;
  --foreground: #fafafa;
  --card: #18181b;
  --card-foreground: #fafafa;
  --border: #27272a;
  --input: #27272a;
  --primary: #3b82f6;
  --primary-foreground: #fafafa;
  --muted: #27272a;
  --muted-foreground: #71717a;
  --accent: #1e293b;
  --accent-foreground: #fafafa;
  --radius: 0.5rem;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  background: var(--background);
  color: var(--foreground);
  font-family: "Inter", "Geist", system-ui, sans-serif;
  font-size: 14px;
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}

::-webkit-scrollbar       { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: #09090b; }
::-webkit-scrollbar-thumb { background: #3f3f46; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: #52525b; }
EOF

# ── components/layout/Shell.tsx ────────────────────────────────────────────
cat > components/layout/Shell.tsx << 'EOF'
// Pontic — App Shell

"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { clsx } from "clsx";
import {
  BarChart2, Globe, TrendingUp, Activity, Zap
} from "lucide-react";

const NAV = [
  { href: "/",           label: "Regime",     icon: Zap       },
  { href: "/signals",    label: "Signals",    icon: Activity  },
  { href: "/indicators", label: "Indicators", icon: BarChart2 },
  { href: "/countries",  label: "Countries",  icon: Globe     },
  { href: "/markets",    label: "Markets",    icon: TrendingUp},
];

export default function Shell({ children }: { children: React.ReactNode }) {
  const path = usePathname();

  return (
    <div className="min-h-screen bg-[#09090b] flex flex-col">
      {/* Top nav */}
      <header className="border-b border-zinc-800 bg-[#09090b]/95 backdrop-blur sticky top-0 z-50">
        <div className="max-w-screen-xl mx-auto px-6 h-14 flex items-center justify-between">
          <div className="flex items-center gap-8">
            {/* Logo */}
            <Link href="/" className="flex items-center gap-2">
              <span className="text-blue-500 font-bold text-lg tracking-tight">PONTIC</span>
              <span className="text-zinc-600 text-xs font-mono mt-0.5">MACRO</span>
            </Link>
            {/* Nav links */}
            <nav className="flex items-center gap-1">
              {NAV.map(({ href, label, icon: Icon }) => (
                <Link
                  key={href}
                  href={href}
                  className={clsx(
                    "flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm transition-colors",
                    path === href
                      ? "bg-zinc-800 text-white"
                      : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50"
                  )}
                >
                  <Icon size={14} />
                  {label}
                </Link>
              ))}
            </nav>
          </div>
          {/* Status indicator */}
          <div className="flex items-center gap-2 text-xs text-zinc-500">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
            Live · 3min refresh
          </div>
        </div>
      </header>

      {/* Page content */}
      <main className="flex-1 max-w-screen-xl mx-auto w-full px-6 py-8">
        {children}
      </main>

      {/* Footer */}
      <footer className="border-t border-zinc-800 py-4 text-center text-xs text-zinc-600">
        Pontic · Global Macro Intelligence · Data: FRED, World Bank, OECD, ECB, BLS, Yahoo Finance
      </footer>
    </div>
  );
}
EOF

# ── components/cards/RegimeCard.tsx ───────────────────────────────────────
cat > components/cards/RegimeCard.tsx << 'EOF'
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
EOF

# ── components/cards/SignalRow.tsx ─────────────────────────────────────────
cat > components/cards/SignalRow.tsx << 'EOF'
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
EOF

# ── components/cards/CountryCard.tsx ──────────────────────────────────────
cat > components/cards/CountryCard.tsx << 'EOF'
// Pontic — Country Card

import { Country } from "@/lib/api";
import { fmt, fmtPct, GROWTH_COLORS } from "@/lib/format";
import { clsx } from "clsx";

const FLAG: Record<string, string> = {
  US:"🇺🇸", GB:"🇬🇧", DE:"🇩🇪", FR:"🇫🇷", JP:"🇯🇵",
  CN:"🇨🇳", IN:"🇮🇳", BR:"🇧🇷", CA:"🇨🇦", AU:"🇦🇺", EU:"🇪🇺"
};

export default function CountryCard({ country }: { country: Country }) {
  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5 hover:border-zinc-600 transition-colors">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <span className="text-2xl">{FLAG[country.country_code] || "🌍"}</span>
          <div>
            <p className="text-sm font-semibold text-zinc-100">{country.country_name}</p>
            <p className="text-xs text-zinc-500 font-mono">{country.country_code}</p>
          </div>
        </div>
        <span className={clsx(
          "text-xs font-semibold px-2 py-0.5 rounded-full",
          country.growth_signal === "EXPANDING"   && "bg-emerald-950 text-emerald-400",
          country.growth_signal === "STABLE"      && "bg-blue-950 text-blue-400",
          country.growth_signal === "SLOWING"     && "bg-amber-950 text-amber-400",
          country.growth_signal === "CONTRACTING" && "bg-red-950 text-red-400",
        )}>
          {country.growth_signal}
        </span>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {[
          { label: "GDP",          value: country.gdp_trillions_usd != null ? `$${fmt(country.gdp_trillions_usd)}T` : "—" },
          { label: "Inflation",    value: fmtPct(country.cpi_inflation_pct) },
          { label: "Debt/GDP",     value: fmtPct(country.debt_to_gdp_pct)  },
          { label: "Unemployment", value: fmtPct(country.unemployment_pct) },
          { label: "CLI",          value: fmt(country.cli_index)            },
          { label: "FDI",          value: country.fdi_inflows_billions_usd != null
              ? `$${fmt(country.fdi_inflows_billions_usd)}B` : "—"         },
        ].map(({ label, value }) => (
          <div key={label} className="bg-zinc-800/50 rounded-lg p-2.5">
            <p className="text-xs text-zinc-500 mb-0.5">{label}</p>
            <p className="text-sm font-mono font-semibold text-zinc-200">{value}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

# ── app/layout.tsx ─────────────────────────────────────────────────────────
cat > app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import "./globals.css";
import Shell from "@/components/layout/Shell";

export const metadata: Metadata = {
  title: "Pontic — Global Macro Intelligence",
  description: "Real-time global macro data, signals, and regime classification.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body>
        <Shell>{children}</Shell>
      </body>
    </html>
  );
}
EOF

# ── app/page.tsx — Regime Dashboard ───────────────────────────────────────
cat > app/page.tsx << 'EOF'
// Pontic — Regime Dashboard (home page)

import { api } from "@/lib/api";
import RegimeCard from "@/components/cards/RegimeCard";
import SignalRow from "@/components/cards/SignalRow";

export const revalidate = 180;

export default async function HomePage() {
  const [regime, extremes] = await Promise.all([
    api.regime(),
    api.extremes(1.0),
  ]);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-zinc-100 mb-1">Macro Regime</h1>
        <p className="text-sm text-zinc-500">
          Real-time classification of the global macro environment based on growth and inflation signals.
        </p>
      </div>

      {/* Regime card */}
      <RegimeCard regime={regime} />

      {/* 2x2 regime matrix */}
      <div className="grid grid-cols-2 gap-3">
        {[
          { name: "GOLDILOCKS",  desc: "Growth ↑ · Inflation ↓", color: "emerald" },
          { name: "REFLATION",   desc: "Growth ↑ · Inflation ↑", color: "amber"   },
          { name: "DEFLATION",   desc: "Growth ↓ · Inflation ↓", color: "blue"    },
          { name: "STAGFLATION", desc: "Growth ↓ · Inflation ↑", color: "red"     },
        ].map(({ name, desc, color }) => (
          <div key={name} className={`rounded-lg border p-4 ${
            regime.regime === name
              ? `bg-${color}-950 border-${color}-800`
              : "bg-zinc-900 border-zinc-800 opacity-40"
          }`}>
            <p className={`text-sm font-semibold text-${color}-400`}>{name}</p>
            <p className="text-xs text-zinc-500 mt-0.5">{desc}</p>
          </div>
        ))}
      </div>

      {/* Supporting signals table */}
      <div>
        <h2 className="text-base font-semibold text-zinc-200 mb-4">
          Elevated Signals
          <span className="ml-2 text-xs text-zinc-500 font-normal">
            indicators with z-score above 1.0
          </span>
        </h2>
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-zinc-800">
                {["Indicator", "Value", "MoM", "YoY", "Z-Score", "Label", "Date"].map(h => (
                  <th key={h} className="py-3 px-4 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider last:text-right">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {extremes.extremes.map(ind => (
                <SignalRow key={`${ind.series_key}-${ind.country_code}`} ind={ind} />
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
EOF

# ── app/indicators/page.tsx ────────────────────────────────────────────────
cat > app/indicators/page.tsx << 'EOF'
// Pontic — All Indicators Page

import { api } from "@/lib/api";
import SignalRow from "@/components/cards/SignalRow";

export const revalidate = 180;

export default async function IndicatorsPage() {
  const data = await api.indicators();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-zinc-100 mb-1">Macro Indicators</h1>
        <p className="text-sm text-zinc-500">
          {data.count} indicators tracked · ranked by z-score extremity
        </p>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-zinc-800">
              {["Indicator", "Value", "MoM", "YoY", "Z-Score", "Label", "Date"].map(h => (
                <th key={h} className="py-3 px-4 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider last:text-right">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.indicators.map(ind => (
              <SignalRow key={`${ind.series_key}-${ind.country_code}`} ind={ind} />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF

# ── app/countries/page.tsx ─────────────────────────────────────────────────
cat > app/countries/page.tsx << 'EOF'
// Pontic — Countries Page

import { api } from "@/lib/api";
import CountryCard from "@/components/cards/CountryCard";

export const revalidate = 180;

export default async function CountriesPage() {
  const data = await api.countries();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-zinc-100 mb-1">Country Intelligence</h1>
        <p className="text-sm text-zinc-500">
          Latest macro snapshot for {data.count} economies · ranked by GDP
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {data.countries.map(country => (
          <CountryCard key={country.country_code} country={country} />
        ))}
      </div>
    </div>
  );
}
EOF

# ── app/signals/page.tsx ───────────────────────────────────────────────────
cat > app/signals/page.tsx << 'EOF'
// Pontic — Signals Page

import { api } from "@/lib/api";
import SignalRow from "@/components/cards/SignalRow";

export const revalidate = 180;

export default async function SignalsPage() {
  const extremes = await api.extremes(0.5);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-zinc-100 mb-1">Signal Board</h1>
        <p className="text-sm text-zinc-500">
          {extremes.count} indicators with z-score above 0.5 · most anomalous readings first
        </p>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-zinc-800">
              {["Indicator", "Value", "MoM", "YoY", "Z-Score", "Label", "Date"].map(h => (
                <th key={h} className="py-3 px-4 text-left text-xs font-medium text-zinc-500 uppercase tracking-wider last:text-right">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {extremes.extremes.map(ind => (
              <SignalRow key={`${ind.series_key}-${ind.country_code}`} ind={ind} />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF

# ── app/markets/page.tsx ───────────────────────────────────────────────────
cat > app/markets/page.tsx << 'EOF'
// Pontic — Markets Page

import { api } from "@/lib/api";
import { fmt, fmtPct, TREND_COLORS } from "@/lib/format";
import { clsx } from "clsx";

export const revalidate = 180;

export default async function MarketsPage() {
  const data = await api.market();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-zinc-100 mb-1">Market Proxies</h1>
        <p className="text-sm text-zinc-500">
          Key market signals as macro context indicators
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {data.signals.map(signal => (
          <div key={signal.series_key}
            className="bg-zinc-900 border border-zinc-800 rounded-xl p-5 hover:border-zinc-600 transition-colors">
            <div className="flex items-start justify-between mb-4">
              <div>
                <p className="text-xs text-zinc-500 font-mono mb-0.5">{signal.ticker}</p>
                <p className="text-sm font-semibold text-zinc-100">{signal.asset_name}</p>
              </div>
              <span className={clsx(
                "text-xs font-semibold px-2 py-0.5 rounded-full",
                signal.trend_signal === "STRONG_UP"   && "bg-emerald-950 text-emerald-400",
                signal.trend_signal === "UP"          && "bg-emerald-950/50 text-emerald-500",
                signal.trend_signal === "DOWN"        && "bg-red-950/50 text-red-500",
                signal.trend_signal === "STRONG_DOWN" && "bg-red-950 text-red-400",
              )}>
                {signal.trend_signal.replace("_", " ")}
              </span>
            </div>

            <div className="grid grid-cols-2 gap-3">
              {[
                { label: "Price",    value: `$${fmt(signal.latest_price)}`   },
                { label: "SMA 20",   value: `$${fmt(signal.sma_20)}`         },
                { label: "1M Return",value: fmtPct(signal.return_1m_pct)     },
                { label: "3M Return",value: fmtPct(signal.return_3m_pct)     },
              ].map(({ label, value }) => (
                <div key={label} className="bg-zinc-800/50 rounded-lg p-2.5">
                  <p className="text-xs text-zinc-500 mb-0.5">{label}</p>
                  <p className="text-sm font-mono font-semibold text-zinc-200">{value}</p>
                </div>
              ))}
            </div>

            <div className="mt-3 flex items-center gap-1.5">
              <div className={clsx(
                "w-2 h-2 rounded-full",
                signal.above_sma20 ? "bg-emerald-500" : "bg-red-500"
              )} />
              <p className="text-xs text-zinc-500">
                {signal.above_sma20 ? "Above" : "Below"} 20-day moving average
              </p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

# ── .env.local ─────────────────────────────────────────────────────────────
cat > .env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF

echo "✅ Frontend files written"
