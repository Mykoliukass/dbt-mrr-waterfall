{{ config(
    materialized='table',
    alias='mrr_waterfall'
) }}

SELECT
    month::DATE AS month,
    initial_subscription_count,
    starting_mrr,
    new_subscription_count,
    new_mrr,
    churned_account_count,
    churned_mrr,
    total_refunds,
    ending_mrr,
    new_mrr_growth_pct,
    churn_mrr_rate_pct,
    net_mrr_growth_pct
FROM {{ ref('int_mrr_final') }}
