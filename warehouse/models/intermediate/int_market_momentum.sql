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
            ((close_price - LAG(close_price, 21) OVER (
                PARTITION BY series_key ORDER BY date
            )) / NULLIF(LAG(close_price, 21) OVER (
                PARTITION BY series_key ORDER BY date
            ), 0) * 100)::NUMERIC,
        2) AS return_1m_pct,

        -- 3-month return
        ROUND(
            ((close_price - LAG(close_price, 63) OVER (
                PARTITION BY series_key ORDER BY date
            )) / NULLIF(LAG(close_price, 63) OVER (
                PARTITION BY series_key ORDER BY date
            ), 0) * 100)::NUMERIC,
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
