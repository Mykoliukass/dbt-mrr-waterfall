WITH initial_mrr AS (
    SELECT
        month_start,
        initial_subscription_count,
        initial_mrr
    FROM {{ ref('int_mrr_initial') }}
),

new_mrr AS (
    SELECT
        month_start,
        new_subscription_count,
        new_sub_mrr
    FROM {{ ref('int_mrr_new_subscriptions') }}
),

churned_mrr AS (
    SELECT
        churn_month AS month_start,
        churned_account_count,
        churned_mrr,
        total_refunds
    FROM {{ ref('int_mrr_churn') }}
),

mrr_movements AS (
    SELECT
        COALESCE(i.month_start, n.month_start, c.month_start) AS month_start,
        COALESCE(i.initial_subscription_count, 0) AS initial_subscription_count,
        COALESCE(i.initial_mrr, 0) AS initial_mrr,
        COALESCE(n.new_subscription_count, 0) AS new_subscription_count,
        COALESCE(n.new_sub_mrr, 0) AS new_mrr,
        COALESCE(c.churned_account_count, 0) AS churned_account_count,
        COALESCE(c.churned_mrr, 0) AS churned_mrr,
        COALESCE(c.total_refunds, 0) AS total_refunds
    FROM initial_mrr i
    FULL OUTER JOIN new_mrr n 
        ON i.month_start = n.month_start
    FULL OUTER JOIN churned_mrr c 
        ON COALESCE(i.month_start, n.month_start) = c.month_start
)

SELECT
    month_start AS month,
    initial_subscription_count,
    initial_mrr AS starting_mrr,
    new_subscription_count,
    new_mrr,
    churned_account_count,
    churned_mrr,
    total_refunds,
    initial_mrr + new_mrr - churned_mrr - total_refunds AS ending_mrr,
    ROUND(
        CASE 
            WHEN initial_mrr > 0 
            THEN (new_mrr / initial_mrr) * 100 
            ELSE 0 
        END, 
        2
    ) AS new_mrr_growth_pct,
    ROUND(
        CASE 
            WHEN initial_mrr > 0 
            THEN (churned_mrr / initial_mrr) * 100 
            ELSE 0 
        END, 
        2
    ) AS churn_mrr_rate_pct,
    ROUND(
        CASE 
            WHEN initial_mrr > 0 
            THEN ((new_mrr - churned_mrr - total_refunds) / initial_mrr) * 100 
            ELSE 0 
        END, 
        2
    ) AS net_mrr_growth_pct
FROM mrr_movements
ORDER BY month_start