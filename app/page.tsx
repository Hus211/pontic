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
