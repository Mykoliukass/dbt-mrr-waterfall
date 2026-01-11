# Oxylabs Analytics Engineer - MRR Waterfall dbt Project

## Project Overview

This dbt project implements a Monthly Recurring Revenue (MRR) waterfall model for Company X, a synthetic SaaS company. The waterfall tracks how MRR changes from month to month, categorizing movements into new revenue, expansion, contraction, and churn.

## Database Setup

This project uses **DuckDB** as the database engine.

### Prerequisites

1. Install dbt-duckdb:
```bash
pip install dbt-duckdb
```

2. Configure your `~/.dbt/profiles.yml`:

```yaml
oxylabs_saastask:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: "C:/Users/mykol/data_projects/dbt/oxylabs_saastask/oxylabs.duckdb"
      threads: 4
    prod:
      type: duckdb
      path: "C:/Users/mykol/data_projects/dbt/oxylabs_saastask/oxylabs.duckdb"
      threads: 4
```

**Note:** Update the `path` to match your local directory structure.

## Project Structure

```
oxylabs_saastask/
├── models/
│   ├── raw_/                    # Raw data layer (CSV seeds materialized as tables)
│   │   ├── raw_accounts.sql
│   │   ├── raw_subscriptions.sql
│   │   ├── raw_feature_usage.sql
│   │   ├── raw_support_tickets.sql
│   │   ├── raw_churn_events.sql
│   │   └── schema.yml
│   ├── staging_/                # Staging layer (cleaned, type-cast data)
│   │   ├── stg_accounts.sql
│   │   ├── stg_subscriptions.sql
│   │   ├── stg_feature_usage.sql
│   │   ├── stg_support_tickets.sql
│   │   ├── stg_churn_events.sql
│   │   └── schema.yml
│   ├── intermediate_/           # Business logic transformations
│       └── rpt_mrr_waterfall.sql
│   └── reporting_/              # Final analytics models
│       ├── int_mrr_initial.sql
│       ├── int_mrr_new_subscriptions.sql
│       ├── int_mrr_churn.sql
│       └── int_mrr_final.sql
├── tests/                       # Custom business logic tests
│   |── test_churn_date_after_subscription_end.sql
│   |── test_assert_no_negative_mrr.sql
│   └── test_assert_mrr_waterfall_integrity.sql
├── data/                        # CSV seed files
│   ├── accounts.csv
│   ├── subscriptions.csv
│   ├── feature_usage.csv
│   ├── support_tickets.csv
│   └── churn_events.csv
└── dbt_project.yml
```

## Data Model Architecture

### Layer Descriptions

1. **Raw Layer (`raw_`)**: Direct representation of source CSV files, materialized as tables in DuckDB
2. **Staging Layer (`staging_`)**: Cleaned and standardized data with consistent naming and typing
3. **Intermediate Layer (`intermediate_`)**: Business logic transformations
4. **Reporting Layer (`reporting_`)**: Final analytics models ready for consumption

### Data Relationships

```
accounts (PK: account_id)
│
├── subscriptions (FK → accounts.account_id)
│   └── feature_usage (FK → subscriptions.subscription_id)
│
├── support_tickets (FK → accounts.account_id)
└── churn_events (FK → accounts.account_id)
```

## Setup Instructions

### 1. Clone the repository
```bash
git clone <repository-url>
cd oxylabs_saastask
```

### 2. Install dependencies
```bash
pip install dbt-core dbt-duckdb
```

### 3. Configure profiles.yml
Update your `~/.dbt/profiles.yml` with the DuckDB configuration shown above.

### 4. Load CSV files to tables
```bash
dbt run --select models/raw_
```

### 5. Build all models
```bash
dbt build
```

Or run models and tests separately:
```bash
dbt run
dbt test
```

## Key Modeling Decisions

### 1. DuckDB Selection
- **Why DuckDB?** Lightweight, embedded database perfect for local development and analytical workloads
- No separate server setup required
- Excellent performance for analytical queries
- Native support for reading CSV files

### 2. Layered Architecture
- **Raw Layer**: Preserves source data integrity, materialized as tables for testing
- **Staging Layer**: Type casting, renaming, and basic cleansing
- **Intermediate Layer**: Main business logic trnasformations
- **Reporting Layer**: Business-ready aggregations and metrics

### 3. MRR Waterfall Logic
The waterfall categorizes MRR movements into:
- **Starting**: Revenue from new subscriptions that existed prior to current month
- **New**: Revenue from new subscriptions that didn't exist in prior month
- **Churn**: Revenue lost from subscriptions that ended
- **Refund**: Revenue lost due to refunds to churned users

### 4. Date Logic Assumptions
- MRR is calculated on a monthly basis using subscription start/end dates
- Active subscriptions (end_date IS NULL or end_date > analyzed_month) contribute to analyzed month MRR
- Subscription changes mid-month are attributed to the month of change
- Trial subscriptions (is_trial = TRUE) are excluded from MRR calculations

## Data Quality Tests

### Generic Tests (13 total)
Implemented in `schema.yml` files using dbt's built-in test types:

1. **Foreign Key Relationships** (4 tests):
   - `raw_subscriptions.account_id` → `raw_accounts.account_id`
   - `raw_feature_usage.subscription_id` → `raw_subscriptions.subscription_id`
   - `raw_support_tickets.account_id` → `raw_accounts.account_id`
   - `raw_churn_events.account_id` → `raw_accounts.account_id`

2. **Uniqueness & Not Null Tests:** (9 tests)
    - `month` - Unique (ensures no duplicate months) + Not Null
    - `initial_subscription_count` - Not Null
    - `starting_mrr` - Not Null
    - `new_subscription_count` - Not Null
    - `new_mrr` - Not Null
    - `churned_account_count` - Not Null
    - `churned_mrr` - Not Null
    - `ending_mrr` - Not Null

### Custom Business Logic Tests (3 test)
Implemented in `tests/` folder:

1. **Churn Date Validation**: 
   - Ensures `churn_date` in `churn_events` occurs on or after subscription `end_date`
   - Validates temporal consistency between subscription lifecycle and churn events
   - Located: `tests/test_churn_date_after_subscription_end.sql`

2. **MRR Waterfall Integrity**: 
   - Validates that the waterfall calculation balances correctly
   - Formula: ending_mrr = starting_mrr + new_mrr - churned_mrr - total_refunds
   - Ensures mathematical accuracy of MRR movements with tolerance of ±$0.01 for rounding
   - Located: `tests/test_assert_mrr_waterfall_integrity.sql`

3. **No Negative MRR Values**: 
   - Ensures all MRR amounts are non-negative (≥ 0)
   - Validates: starting_mrr, new_mrr, churned_mrr, ending_mrr
   - Located: `tests/test_assert_no_negative_mrr.sql`

**Total: 17 tests** 

## Running Tests

```bash
# Run all tests
dbt test

# Run only custom tests
dbt test --select test_type:singular

# Run only generic tests
dbt test --select test_type:generic

# Run specific test
dbt test --select test_churn_date_after_subscription_end
```

## Known Limitations & Edge Cases

### Current Implementation

1. **Monthly Granularity**: MRR is calculated at monthly level; intra-month changes are simplified
2. **Multiple Subscriptions**: Accounts can have multiple overlapping subscriptions - current model sums all active subscriptions
3. **Trial Handling**: Trials are excluded from MRR calculation
4. **Billing Frequency**: Annual subscriptions are converted to MRR (ARR/12) but this may not reflect actual cash collection timing

### Edge Cases Identified

1. **Same-Month Start and End**: Subscriptions that start and end in the same month
2. **Upgrades/Downgrades**: No information is available about price changes with upgrades/downgrades
3. **Backdated Subscriptions**: Historical data loads where subscription dates precede signup_date

## Production Improvements

### Scalability & Performance
1. **Incremental Models**: Implement incremental materialization for large tables (mrr_waterfall)
   ```sql
   {{ config(materialized='incremental', unique_key='month') }}
   ```
2. **Partitioning**: Partition large tables by date (year/month) for better query performance (depends on used database).
3. **Indexing Strategy**: Add indexes on frequently joined columns (account_id, subscription_id)
4. **Query Optimization**: Use CTEs judiciously, consider materializing complex intermediate calculations
5. **Orhcestration**: Use Airflow, add execution_date variable to dbt for incremental logic.

### Data Freshness & Incremental Strategies
1. **Source Freshness Tests**: Implement dbt source freshness checks
   ```yaml
   sources:
     - name: raw_data
       freshness:
         warn_after: {count: 6, period: hour}
         error_after: {count: 12, period: hour}
   ```
2. **Incremental Loading**: 
   - Load only new/changed records based on `updated_at` timestamps
3. **Snapshot Models**: Use dbt snapshots for slowly changing dimensions (account attributes, plan tiers)

### Monitoring & Data Quality
1. **Automated Testing**: 
   - Add dbt test results to data observability platform
   - Set up Slack/email alerts for test failures
2. **Data Quality Metrics**:
   - Track test pass rates over time
   - Monitor row counts and null percentages
   - Alert on anomalous MRR movements (>X% month-over-month change)
3. **Model Performance Monitoring**:
   - Log execution times for models
   - Alert on models exceeding SLA thresholds
4. **Data Lineage**: Use dbt docs to maintain clear documentation of data transformations
5. **Additional Business Logic Tests**:
   - MRR waterfall balance test (beginning + changes = ending)
   - No negative MRR values
   - Subscription date logic (end_date >= start_date)

### Operational Excellence
1. **Environment Management**: Separate dev/staging/prod environments with different data samples
2. **CI/CD Integration**: Run `dbt test` and `dbt build` in CI pipeline before deployment
3. **Version Control**: Tag releases, maintain changelog for model changes

## Repository

GitHub: [[Link to repository](https://github.com/Mykoliukass/dbt-mrr-waterfall/)]