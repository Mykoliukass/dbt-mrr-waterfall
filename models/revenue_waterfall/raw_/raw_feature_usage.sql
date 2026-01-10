{{ config(materialized='table') }}

SELECT
    usage_id,
    subscription_id,
    usage_date,
    feature_name,
    usage_count,
    usage_duration_secs,
    error_count,
    is_beta_feature
FROM read_csv_auto('data/feature_usage.csv')
