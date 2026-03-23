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
