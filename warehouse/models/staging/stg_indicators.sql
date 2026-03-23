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
