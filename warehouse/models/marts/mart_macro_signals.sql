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
