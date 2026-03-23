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
