WITH date_spine AS (
    SELECT date_trunc('month', value)::DATE AS month_start
    FROM generate_series(
        (SELECT min(churn_date) FROM {{ ref('stg_churn_events') }}),
        (SELECT max(churn_date) FROM {{ ref('stg_churn_events') }}),
        INTERVAL 1 MONTH
    ) AS gs(value)
),

churn_subscriptions AS (
    SELECT
        date_trunc('month', ce.churn_date)::DATE AS churn_month,
        ce.churn_event_id,
        ce.account_id,
        ce.churn_date,
        ce.reason_code,
        ce.refund_amount_usd,
        ce.preceding_upgrade_flag,
        ce.preceding_downgrade_flag,
        ce.is_reactivation,
        s.subscription_id,
        s.plan_tier,
        s.seats,
        s.mrr_amount,
        s.arr_amount,
        s.billing_frequency
    FROM {{ ref('stg_churn_events') }} AS ce
    INNER JOIN {{ ref('stg_subscriptions') }} AS s
        ON ce.account_id = s.account_id
        AND ce.churn_date >= s.start_date
        AND (s.end_date IS NULL OR ce.churn_date <= s.end_date)
        AND s.churn_flag = TRUE
)

SELECT
    churn_month,
    COUNT(DISTINCT account_id) AS churned_account_count,
    SUM(mrr_amount) AS churned_mrr,
    SUM(refund_amount_usd)::NUMERIC(38,2) AS total_refunds
FROM churn_subscriptions
GROUP BY churn_month
