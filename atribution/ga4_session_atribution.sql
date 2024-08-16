-- Carregamento da tabela 
WITH ga4_fresh_table AS (
  SELECT 
    event_date,
    TIMESTAMP_MICROS(event_timestamp) AS event_timestamp,
    event_name,
    device.category AS device_category,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE KEY = 'ga_session_id') AS session_id,
    session_traffic_source_last_click.manual_campaign.source AS session_source, 
    collected_traffic_source.manual_source AS session_source_manual,
    session_traffic_source_last_click.manual_campaign.medium AS session_medium,
    collected_traffic_source.manual_medium AS session_medium_manual,
    ecommerce.transaction_id AS transaction_id,
    ecommerce.purchase_revenue AS revenue
  FROM `project.dataset.table_*` -- mudar dataset
  --WHERE _TABLE_SUFFIX BETWEEN '20240713' AND '20240813'
),

-- Extração e formatação
raw_data AS (
  SELECT
    PARSE_DATE("%Y%m%d", event_date) AS event_date,
    DATETIME(TIMESTAMP_TRUNC(event_timestamp, HOUR), "America/Sao_Paulo") data_hora,
    event_name,
    device_category,
    user_pseudo_id,
    session_id,
    session_source, 
    session_source_manual,
    session_medium,
    session_medium_manual,
    CASE
        WHEN
          event_name = 'purchase'
          AND transaction_id IS NOT NULL
          AND IFNULL(LOWER(transaction_id),'') <> '(not set)'
        THEN transaction_id
        ELSE NULL
      END AS transaction_id,
    revenue
  FROM ga4_fresh_table
),

set_referral AS (
  SELECT 
    *,
    CASE
      WHEN LOWER(IFNULL(session_source, session_source_manual)) LIKE "%google%" AND LOWER(IFNULL(session_medium, session_medium_manual)) IN ('s', 'g', 'x', 'd') THEN "google"
      WHEN LOWER(IFNULL(session_source, session_source_manual)) LIKE "%bing%" AND LOWER(IFNULL(session_medium, session_medium_manual)) IN ('o', 's', 'a') THEN "bing"
      WHEN LOWER(IFNULL(session_source, session_source_manual)) = "(not set)" THEN "(direct)" -- tratamento para not set
      ELSE IFNULL(session_source, session_source_manual)
    END AS final_source,
    CASE
      WHEN LOWER(IFNULL(session_source, session_source_manual)) LIKE "%google%" AND LOWER(IFNULL(session_medium, session_medium_manual)) IN ('s', 'g', 'x', 'd') THEN "cpc"
      WHEN LOWER(IFNULL(session_source, session_source_manual)) LIKE "%bing%" AND LOWER(IFNULL(session_medium, session_medium_manual)) IN ('o', 's', 'a') THEN "cpc"
      WHEN LOWER(IFNULL(session_source, session_source_manual)) = "google" AND IFNULL(session_medium, session_medium_manual) IS NULL THEN "organic" -- new line
      WHEN LOWER(IFNULL(session_medium, session_medium_manual)) = "(not set)" THEN "(none)" -- tratamento para not set
      ELSE IFNULL(session_medium, session_medium_manual)
    END AS final_medium
  FROM raw_data
)

SELECT
    event_date,
    data_hora,
    device_category,
    COALESCE(final_source, "(direct)") session_source,
    COALESCE(final_medium, "(none)") session_medium,
    CONCAT(COALESCE(final_source, "(direct)"), ' / ', COALESCE(final_medium, "(none)")) AS session_source_medium,
    COUNT(DISTINCT user_pseudo_id||session_id) AS sessions,
    COUNT(DISTINCT user_pseudo_id) AS total_users,
    COUNT(transaction_id) AS transactions,
    SAFE_DIVIDE(COUNT(transaction_id), COUNT(DISTINCT user_pseudo_id||session_id)) AS conversion_rate,
    SUM(revenue) AS revenue
FROM 
  set_referral
GROUP BY
    event_date,
    data_hora,
    device_category,
    session_source,
    session_medium,
    session_source_medium