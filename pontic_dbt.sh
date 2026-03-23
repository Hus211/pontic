#!/bin/bash
# Pontic — Layer 2: dbt models

# ── staging models ─────────────────────────────────────────────────────────

cat > warehouse/models/staging/stg_indicators.sql << 'EOF'
-- Pontic: Staging — US macro indicators (FRED, ECB, BLS)
-- Cleans types, standardises column names, filters nulls

WITH source AS (
    SELECT * FROM {{ source('pontic_raw', 'raw_indicators') }}
),

cleaned AS (
    SELECT
        source                                      AS source,
        series_key                                  AS series_key,
        COALESCE(series_id, series_key)             AS series_id,
        name                                        AS indicator_name,
        unit                                        AS unit,
        COALESCE(frequency, 'monthly')              AS frequency,
        COALESCE(country_code, 'US')                AS country_code,
        date::DATE                                  AS date,
        value::DOUBLE PRECISION                     AS value,
        fetched_at                                  AS fetched_at
    FROM source
    WHERE
        value IS NOT NULL
        AND date IS NOT NULL
        AND date >= '2000-01-01'
)

SELECT * FROM cleaned
EOF

cat > warehouse/models/staging/stg_country_indicators.sql << 'EOF'
-- Pontic: Staging — Global country indicators (World Bank, OECD)

WITH source AS (
    SELECT * FROM {{ source('pontic_raw', 'raw_country_indicators') }}
),

cleaned AS (
    SELECT
        source                          AS source,
        series_key                      AS series_key,
        COALESCE(indicator_id, series_key) AS indicator_id,
        name                            AS indicator_name,
        COALESCE(unit, '')              AS unit,
        country_code                    AS country_code,
        COALESCE(country_name, country_code) AS country_name,
        date::DATE                      AS date,
        value::DOUBLE PRECISION         AS value,
        fetched_at                      AS fetched_at
    FROM source
    WHERE
        value IS NOT NULL
        AND date IS NOT NULL
        AND country_code IS NOT NULL
        AND date >= '2000-01-01'
)

SELECT * FROM cleaned
EOF

cat > warehouse/models/staging/stg_market_proxies.sql << 'EOF'
-- Pontic: Staging — Market proxy data (yfinance)

WITH source AS (
    SELECT * FROM {{ source('pontic_raw', 'raw_market_proxies') }}
),

cleaned AS (
    SELECT
        source                          AS source,
        series_key                      AS series_key,
        COALESCE(ticker, series_key)    AS ticker,
        name                            AS asset_name,
        COALESCE(category, 'unknown')   AS category,
        COALESCE(unit, 'USD')           AS unit,
        date::DATE                      AS date,
        value::DOUBLE PRECISION         AS close_price,
        COALESCE(volume, 0)             AS volume,
        fetched_at                      AS fetched_at
    FROM source
    WHERE
        value IS NOT NULL
        AND date IS NOT NULL
        AND date >= '2000-01-01'
)

SELECT * FROM cleaned
EOF

# ── sources.yml ────────────────────────────────────────────────────────────
cat > warehouse/models/staging/sources.yml << 'EOF'
version: 2

sources:
  - name: pontic_raw
    schema: public
    description: "Raw ingested macro data from all 6 sources"
    tables:
      - name: raw_indicators
        description: "US macro indicators: FRED, ECB, BLS"
        columns:
          - name: source
            description: "Data source name"
          - name: series_key
            description: "Internal series identifier"
          - name: date
            description: "Observation date"
          - name: value
            description: "Numeric value of the indicator"

      - name: raw_country_indicators
        description: "Global country indicators: World Bank, OECD"

      - name: raw_market_proxies
        description: "Market proxy data: yfinance tickers"
EOF

# ── intermediate models ────────────────────────────────────────────────────

cat > warehouse/models/intermediate/int_indicators_with_changes.sql << 'EOF'
-- Pontic: Intermediate — Add MoM and YoY % changes to US indicators

WITH base AS (
    SELECT * FROM {{ ref('stg_indicators') }}
),

with_changes AS (
    SELECT
        source,
        series_key,
        indicator_name,
        unit,
        frequency,
        country_code,
        date,
        value,

        -- Month-over-Month change
        LAG(value, 1) OVER (
            PARTITION BY series_key, country_code
            ORDER BY date
        ) AS prev_month_value,

        ROUND(
            (value - LAG(value, 1) OVER (
                PARTITION BY series_key, country_code ORDER BY date
            )) / NULLIF(ABS(LAG(value, 1) OVER (
                PARTITION BY series_key, country_code ORDER BY date
            )), 0) * 100,
        2) AS mom_pct,

        -- Year-over-Year change
        LAG(value, 12) OVER (
            PARTITION BY series_key, country_code
            ORDER BY date
        ) AS prev_year_value,

        ROUND(
            (value - LAG(value, 12) OVER (
                PARTITION BY series_key, country_code ORDER BY date
            )) / NULLIF(ABS(LAG(value, 12) OVER (
                PARTITION BY series_key, country_code ORDER BY date
            )), 0) * 100,
        2) AS yoy_pct,

        fetched_at
    FROM base
)

SELECT * FROM with_changes
EOF

cat > warehouse/models/intermediate/int_indicators_zscore.sql << 'EOF'
-- Pontic: Intermediate — Z-scores to show how extreme current readings are

WITH base AS (
    SELECT * FROM {{ ref('int_indicators_with_changes') }}
),

stats AS (
    SELECT
        series_key,
        country_code,
        AVG(value)    AS mean_val,
        STDDEV(value) AS std_val
    FROM base
    WHERE date >= (CURRENT_DATE - INTERVAL '10 years')
    GROUP BY series_key, country_code
),

with_zscore AS (
    SELECT
        b.*,
        ROUND(
            (b.value - s.mean_val) / NULLIF(s.std_val, 0),
        2) AS zscore,
        s.mean_val,
        s.std_val
    FROM base b
    LEFT JOIN stats s
        ON b.series_key   = s.series_key
        AND b.country_code = s.country_code
)

SELECT * FROM with_zscore
EOF

cat > warehouse/models/intermediate/int_market_momentum.sql << 'EOF'
-- Pontic: Intermediate — Market proxy momentum signals

WITH base AS (
    SELECT * FROM {{ ref('stg_market_proxies') }}
),

with_momentum AS (
    SELECT
        source,
        series_key,
        ticker,
        asset_name,
        category,
        unit,
        date,
        close_price,

        -- 20-day simple moving average
        ROUND(AVG(close_price) OVER (
            PARTITION BY series_key
            ORDER BY date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        )::NUMERIC, 4) AS sma_20,

        -- 50-day simple moving average
        ROUND(AVG(close_price) OVER (
            PARTITION BY series_key
            ORDER BY date
            ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
        )::NUMERIC, 4) AS sma_50,

        -- 1-month return
        ROUND(
            (close_price - LAG(close_price, 21) OVER (
                PARTITION BY series_key ORDER BY date
            )) / NULLIF(LAG(close_price, 21) OVER (
                PARTITION BY series_key ORDER BY date
            ), 0) * 100,
        2) AS return_1m_pct,

        -- 3-month return
        ROUND(
            (close_price - LAG(close_price, 63) OVER (
                PARTITION BY series_key ORDER BY date
            )) / NULLIF(LAG(close_price, 63) OVER (
                PARTITION BY series_key ORDER BY date
            ), 0) * 100,
        2) AS return_3m_pct,

        -- Above SMA20? (trend signal)
        CASE WHEN close_price > AVG(close_price) OVER (
            PARTITION BY series_key
            ORDER BY date
            ROWS BETWEEN 19 PRECEDING AND CURRENT ROW
        ) THEN true ELSE false END AS above_sma20,

        fetched_at
    FROM base
)

SELECT * FROM with_momentum
EOF

# ── mart models ────────────────────────────────────────────────────────────

cat > warehouse/models/marts/mart_macro_signals.sql << 'EOF'
-- Pontic: Mart — Final macro signal table (API primary source)
-- Latest reading per indicator with all derived metrics

WITH latest AS (
    SELECT DISTINCT ON (series_key, country_code)
        *
    FROM {{ ref('int_indicators_zscore') }}
    WHERE value IS NOT NULL
    ORDER BY series_key, country_code, date DESC
)

SELECT
    source,
    series_key,
    indicator_name,
    unit,
    frequency,
    country_code,
    date                        AS latest_date,
    value                       AS latest_value,
    mom_pct,
    yoy_pct,
    zscore,
    mean_val,
    std_val,

    -- Direction signal
    CASE
        WHEN mom_pct  > 0 THEN 'UP'
        WHEN mom_pct  < 0 THEN 'DOWN'
        ELSE 'FLAT'
    END AS mom_direction,

    -- Z-score risk label
    CASE
        WHEN ABS(zscore) > 2   THEN 'EXTREME'
        WHEN ABS(zscore) > 1   THEN 'ELEVATED'
        ELSE                        'NORMAL'
    END AS zscore_label,

    fetched_at
FROM latest
EOF

cat > warehouse/models/marts/mart_country_snapshot.sql << 'EOF'
-- Pontic: Mart — Latest macro snapshot per country
-- Used for country intelligence cards in the dashboard

WITH latest AS (
    SELECT DISTINCT ON (series_key, country_code)
        *
    FROM {{ ref('stg_country_indicators') }}
    WHERE value IS NOT NULL
    ORDER BY series_key, country_code, date DESC
),

pivoted AS (
    SELECT
        country_code,
        country_name,
        MAX(date)                                               AS latest_date,
        MAX(CASE WHEN series_key = 'GDP_USD'       THEN value END) AS gdp_usd,
        MAX(CASE WHEN series_key = 'CPI_INFLATION' THEN value END) AS cpi_inflation_pct,
        MAX(CASE WHEN series_key = 'DEBT_TO_GDP'   THEN value END) AS debt_to_gdp_pct,
        MAX(CASE WHEN series_key = 'UNEMPLOYMENT'  THEN value END) AS unemployment_pct,
        MAX(CASE WHEN series_key = 'FDI_INFLOWS'   THEN value END) AS fdi_inflows_usd,
        MAX(CASE WHEN series_key = 'CLI'           THEN value END) AS cli_index
    FROM latest
    GROUP BY country_code, country_name
)

SELECT
    country_code,
    country_name,
    latest_date,
    ROUND(gdp_usd / 1e12, 2)       AS gdp_trillions_usd,
    ROUND(cpi_inflation_pct, 2)    AS cpi_inflation_pct,
    ROUND(debt_to_gdp_pct, 2)      AS debt_to_gdp_pct,
    ROUND(unemployment_pct, 2)     AS unemployment_pct,
    ROUND(fdi_inflows_usd / 1e9, 2) AS fdi_inflows_billions_usd,
    ROUND(cli_index, 2)            AS cli_index,

    -- Growth signal from CLI
    CASE
        WHEN cli_index > 101  THEN 'EXPANDING'
        WHEN cli_index > 99   THEN 'STABLE'
        WHEN cli_index > 97   THEN 'SLOWING'
        ELSE                       'CONTRACTING'
    END AS growth_signal

FROM pivoted
EOF

cat > warehouse/models/marts/mart_market_snapshot.sql << 'EOF'
-- Pontic: Mart — Latest market proxy readings with momentum

WITH latest AS (
    SELECT DISTINCT ON (series_key)
        *
    FROM {{ ref('int_market_momentum') }}
    WHERE close_price IS NOT NULL
    ORDER BY series_key, date DESC
)

SELECT
    series_key,
    ticker,
    asset_name,
    category,
    unit,
    date                AS latest_date,
    close_price         AS latest_price,
    sma_20,
    sma_50,
    return_1m_pct,
    return_3m_pct,
    above_sma20,

    -- Trend signal
    CASE
        WHEN return_1m_pct > 3   THEN 'STRONG_UP'
        WHEN return_1m_pct > 0   THEN 'UP'
        WHEN return_1m_pct > -3  THEN 'DOWN'
        ELSE                          'STRONG_DOWN'
    END AS trend_signal,

    fetched_at
FROM latest
EOF

# ── schema.yml ─────────────────────────────────────────────────────────────
cat > warehouse/models/marts/schema.yml << 'EOF'
version: 2

models:
  - name: mart_macro_signals
    description: "Latest macro indicator readings with MoM/YoY changes and z-scores"
    columns:
      - name: series_key
        description: "Unique indicator identifier"
      - name: latest_value
        description: "Most recent observed value"
      - name: zscore
        description: "Standard deviations from 10-year mean"
      - name: zscore_label
        description: "NORMAL / ELEVATED / EXTREME"

  - name: mart_country_snapshot
    description: "Latest macro snapshot per country for dashboard cards"
    columns:
      - name: country_code
        description: "ISO country code"
      - name: growth_signal
        description: "EXPANDING / STABLE / SLOWING / CONTRACTING based on CLI"

  - name: mart_market_snapshot
    description: "Latest market proxy prices with momentum signals"
    columns:
      - name: trend_signal
        description: "STRONG_UP / UP / DOWN / STRONG_DOWN based on 1M return"
EOF

echo "✅ dbt models written"
