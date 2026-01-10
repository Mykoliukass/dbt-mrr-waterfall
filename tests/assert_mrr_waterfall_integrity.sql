-- Test that the waterfall calculation is correct
-- This test will FAIL if any rows are returned

SELECT *
FROM {{ ref('mrr_waterfall') }}
WHERE ABS(ending_mrr - (starting_mrr + new_mrr - churned_mrr -total_refunds)) > 0.01
