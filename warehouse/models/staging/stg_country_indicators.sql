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
