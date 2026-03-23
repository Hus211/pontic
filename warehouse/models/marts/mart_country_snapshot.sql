-- Pontic: Mart — Latest macro snapshot per country

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
        MAX(date)                                                   AS latest_date,
        MAX(CASE WHEN series_key = 'GDP_USD'       THEN value END)  AS gdp_usd,
        MAX(CASE WHEN series_key = 'CPI_INFLATION' THEN value END)  AS cpi_inflation_pct,
        MAX(CASE WHEN series_key = 'DEBT_TO_GDP'   THEN value END)  AS debt_to_gdp_pct,
        MAX(CASE WHEN series_key = 'UNEMPLOYMENT'  THEN value END)  AS unemployment_pct,
        MAX(CASE WHEN series_key = 'FDI_INFLOWS'   THEN value END)  AS fdi_inflows_usd,
        MAX(CASE WHEN series_key = 'CLI'           THEN value END)  AS cli_index
    FROM latest
    GROUP BY country_code, country_name
)

SELECT
    country_code,
    country_name,
    latest_date,
    ROUND((gdp_usd / 1e12)::NUMERIC, 2)        AS gdp_trillions_usd,
    ROUND(cpi_inflation_pct::NUMERIC, 2)        AS cpi_inflation_pct,
    ROUND(debt_to_gdp_pct::NUMERIC, 2)          AS debt_to_gdp_pct,
    ROUND(unemployment_pct::NUMERIC, 2)         AS unemployment_pct,
    ROUND((fdi_inflows_usd / 1e9)::NUMERIC, 2) AS fdi_inflows_billions_usd,
    ROUND(cli_index::NUMERIC, 2)                AS cli_index,

    CASE
        WHEN cli_index > 101 THEN 'EXPANDING'
        WHEN cli_index > 99  THEN 'STABLE'
        WHEN cli_index > 97  THEN 'SLOWING'
        ELSE                      'CONTRACTING'
    END AS growth_signal

FROM pivoted
