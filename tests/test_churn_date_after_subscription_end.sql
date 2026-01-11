{{
    config(
        severity='error'
    )
}}

/*
    Custom business logic test: Churn Date Validation
    
    This test ensures that when an account churns, the churn_date in churn_events
    is on or after the subscription's end_date. This validates temporal consistency
    between subscription lifecycle and churn events.
    
    Logic:
    - Join churn_events with subscriptions on account_id
    - Find cases where churn_date < end_date
    - These represent data quality issues where churn is recorded before subscription ended
    
    Expected result: 0 rows (no violations)
*/

WITH churn_events AS (
    SELECT
        churn_event_id,
        account_id,
        churn_date
    FROM {{ ref('raw_churn_events') }}
),

subscriptions AS (
    SELECT
        account_id,
        subscription_id,
        end_date,
        churn_flag
    FROM {{ ref('raw_subscriptions') }}
    WHERE churn_flag = True
        AND end_date IS NOT NULL
),

validation AS (
    SELECT
        ce.churn_event_id,
        ce.account_id,
        ce.churn_date,
        s.subscription_id,
        s.end_date AS subscription_end_date,
        DATEDIFF('day', s.end_date, ce.churn_date) AS days_difference
    FROM churn_events ce
    INNER JOIN subscriptions s
        ON ce.account_id = s.account_id
    WHERE ce.churn_date < s.end_date
)

SELECT
    churn_event_id,
    account_id,
    churn_date,
    subscription_id,
    subscription_end_date,
    days_difference,
    'Churn date (' || churn_date || ') is before subscription end date (' || subscription_end_date || ')' AS validation_error
FROM validation