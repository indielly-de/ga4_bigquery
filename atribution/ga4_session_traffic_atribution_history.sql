WITH analysis_period AS (
  SELECT
    CAST('2024-08-10' AS DATE) AS start_date, 
    CAST('2024-08-15' AS DATE) AS end_date
),

raw_events_data AS (
  SELECT
    CAST(event_date AS DATE format 'YYYYMMDD') AS date,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE KEY = 'ga_session_id') AS ga_session_id,
    user_pseudo_id,
    collected_traffic_source.manual_source,
    collected_traffic_source.manual_medium,
    collected_traffic_source.manual_campaign_name,
    collected_traffic_source.gclid,
    TIMESTAMP_MICROS(event_timestamp) AS event_timestamp,
  FROM
    `project.dataset.table_*`, analysis_period AS d -- mudar dataset
  WHERE
    _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(start_date, INTERVAL 90 DAY)) AND FORMAT_DATE('%Y%m%d', end_date)
),

trusted_events AS (
  SELECT
    * EXCEPT(manual_source, manual_medium, manual_campaign_name, gclid),
    (SELECT AS STRUCT
      (CASE
        WHEN gclid IS NOT NULL AND (manual_campaign_name='(organic)' OR manual_campaign_name IS NULL) THEN 'google'
        ELSE manual_source
      END) AS utm_source,
      (CASE
        WHEN gclid IS NOT NULL AND (manual_campaign_name='(organic)' OR manual_campaign_name IS NULL) THEN 'cpc'
        ELSE manual_medium
      END) AS utm_medium,
      (CASE 
        WHEN manual_source IS NULL AND manual_medium IS NULL AND gclid IS NULL THEN NULL
        WHEN gclid IS NOT NULL AND manual_campaign_name='(organic)' THEN NULL
        ELSE manual_campaign_name 
      END) AS utm_campaign,
      gclid
    ) AS event_source
  FROM
    raw_events_data
),

session_traffic_sources AS (
  SELECT
    date,
    user_pseudo_id,
    ga_session_id,
    ARRAY_AGG(
      (CASE
        WHEN event_source.utm_source IS NOT NULL OR event_source.utm_medium IS NOT NULL THEN event_source
        ELSE NULL END) IGNORE NULLS ORDER BY event_timestamp
    ) [SAFE_OFFSET(0)] AS first_source,
    ARRAY_AGG(
      (CASE
        WHEN event_source.utm_source IS NOT NULL OR event_source.utm_medium IS NOT NULL THEN event_source
        ELSE NULL END) IGNORE NULLS ORDER BY event_timestamp DESC
    ) [SAFE_OFFSET(0)] AS last_source,
  FROM
    trusted_events
  GROUP BY ALL
),

last_non_direct_click_attribution AS (
  SELECT
    date,
    user_pseudo_id,
    ga_session_id,
    first_source,
    last_source,
    IF(first_source.utm_source IS NULL AND first_source.utm_medium IS NULL, last_source, first_source) AS session_source,
    LAST_VALUE(IF(last_source.utm_source IS NOT NULL OR last_source.utm_medium IS NOT NULL, date, NULL) IGNORE NULLS) OVER(PARTITION BY user_pseudo_id ORDER BY
      ga_session_id RANGE BETWEEN 7776000 PRECEDING AND 1 PRECEDING
    ) AS lndc_date, 
    LAST_VALUE(IF(last_source.utm_source IS NOT NULL OR last_source.utm_medium IS NOT NULL, last_source, NULL) IGNORE NULLS) OVER(PARTITION BY user_pseudo_id ORDER BY
      ga_session_id RANGE BETWEEN 7776000 PRECEDING AND 1 PRECEDING
    ) AS lndc
  FROM
    session_traffic_sources
),

validated_source_attribution AS (
  SELECT 
    * EXCEPT(lndc,lndc_date),

    IF(
      session_source.utm_source IS NULL AND session_source.utm_medium IS NULL, 
      lndc, 
      session_source
    ) AS lndc, -- atribuicao

    IF(
      session_source.utm_source IS NULL AND session_source.utm_medium IS NULL, 
      IF(lndc.utm_source IS NULL, date, lndc_date),
      date
    ) AS date_attr, -- data da atribuicao
  FROM 
    last_non_direct_click_attribution
)

SELECT 
  date,
  user_pseudo_id,
  ga_session_id,
  first_source, -- primeiro source da sessão (sem janela)
  last_source, -- ultimo source da sessão (sem janela)
  (SELECT AS STRUCT
    lndc.utm_source,
    lndc.utm_medium,
    lndc.utm_campaign
  ) AS lndc, -- last non direct click = atribuição de tráfego da sessão (com janela de 90 dias)
  date_attr
FROM validated_source_attribution, analysis_period AS d
WHERE
  date BETWEEN d.start_date AND d.end_date