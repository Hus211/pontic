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
            ((value - LAG(value, 1) OVER (
                PARTITION BY series_key, country_code ORDER BY date
            )) / NULLIF(ABS(LAG(value, 1) OVER (
                PARTITION BY series_key, country_code ORDER BY date
            )), 0) * 100)::NUMERIC,
        2) AS mom_pct,

        -- Year-over-Year change
        LAG(value, 12) OVER (
            PARTITION BY series_key, country_code
            ORDER BY date
        ) AS prev_year_value,

        ROUND(
            ((value - LAG(value, 12) OVER (
                PARTITION BY series_key, country_code ORDER BY date
            )) / NULLIF(ABS(LAG(value, 12) OVER (
                PARTITION BY series_key, country_code ORDER BY date
            )), 0) * 100)::NUMERIC,
        2) AS yoy_pct,

        fetched_at
    FROM base
)

SELECT * FROM with_changes
