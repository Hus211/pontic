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
