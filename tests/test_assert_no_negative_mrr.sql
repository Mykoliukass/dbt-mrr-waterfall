-- Test that all MRR values are non-negative
-- This test will FAIL if any rows are returned

SELECT *
FROM {{ ref('mrr_waterfall') }}
WHERE starting_mrr < 0 
   OR new_mrr < 0 
   OR churned_mrr < 0 
   OR ending_mrr < 0
