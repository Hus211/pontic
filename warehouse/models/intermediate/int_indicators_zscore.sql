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
            ((b.value - s.mean_val) / NULLIF(s.std_val, 0))::NUMERIC,
        2) AS zscore,
        s.mean_val,
        s.std_val
    FROM base b
    LEFT JOIN stats s
        ON b.series_key    = s.series_key
        AND b.country_code = s.country_code
)

SELECT * FROM with_zscore
