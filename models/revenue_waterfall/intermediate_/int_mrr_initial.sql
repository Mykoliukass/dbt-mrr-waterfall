WITH date_spine AS (
    SELECT date_trunc('month', value)::DATE AS month_start
    FROM generate_series(
        (SELECT min(start_date) FROM {{ ref('stg_subscriptions') }}),
        (
            SELECT max(coalesce(end_date, start_date))
            FROM {{ ref('stg_subscriptions') }}
        ),
        INTERVAL 1 MONTH
    ) AS gs (value)
),

subscription_months AS (
    SELECT
        d.month_start,
        s.subscription_id,
        s.start_date,
        s.end_date,
        s.mrr_amount
    FROM date_spine AS d
    INNER JOIN {{ ref('stg_subscriptions') }} AS s
        ON
            d.month_start > s.start_date
            AND (s.end_date IS NULL OR d.month_start <= s.end_date)
)

SELECT
    month_start,
    count(DISTINCT subscription_id) AS initial_subscription_count,
    sum(mrr_amount) AS initial_mrr
FROM subscription_months
GROUP BY month_start
