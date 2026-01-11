WITH date_spine AS (
    SELECT date_trunc('month', value)::DATE AS month_start
    FROM generate_series(
        (SELECT min(start_date) FROM {{ ref('stg_subscriptions') }}),
        (SELECT max(coalesce(end_date, start_date)) FROM {{ ref('stg_subscriptions') }}),
        INTERVAL 1 MONTH
    ) AS gs(value)
),

new_subscription_months AS (
    SELECT
        d.month_start,
        s.subscription_id,
        s.account_id,
        s.start_date,
        s.end_date,
        s.mrr_amount
    FROM date_spine AS d
    INNER JOIN {{ ref('stg_subscriptions') }} AS s
        ON date_trunc('month', s.start_date) = d.month_start
        AND s.is_trial = False
)

SELECT
    month_start,
    COUNT(DISTINCT subscription_id) AS new_subscription_count,
    SUM(mrr_amount) AS new_sub_mrr
FROM new_subscription_months
GROUP BY month_start
