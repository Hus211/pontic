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
