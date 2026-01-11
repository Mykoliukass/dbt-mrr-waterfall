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
│   └── reporting_/              # Final analytics models
│       └── rpt_mrr_waterfall.sql
├── tests/                       # Custom business logic tests
│   └── test_churn_date_after_subscription_end.sql
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
3. **Intermediate Layer (`intermediate_`)**: Business logic transformations (if needed)
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
pip install dbt-duckdb
```

### 3. Configure profiles.yml
Update your `~/.dbt/profiles.yml` with the DuckDB configuration shown above.

### 4. Load seed data
```bash
dbt seed
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
- **Reporting Layer**: Business-ready aggregations and metrics

### 3. MRR Waterfall Logic
The waterfall categorizes MRR movements into:
- **New**: Revenue from new subscriptions that didn't exist in prior month
- **Expansion**: Increased revenue from existing subscriptions (upgrades, seat additions)
- **Contraction**: Decreased revenue from existing subscriptions (downgrades, seat reductions)
- **Churn**: Lost revenue from subscriptions that ended
- **Reactivation**: Revenue from previously churned accounts returning

### 4. Date Logic Assumptions
- MRR is calculated on a monthly basis using subscription start/end dates
- Active subscriptions (end_date IS NULL) contribute to current month MRR
- Subscription changes mid-month are attributed to the month of change
- Trial subscriptions (is_trial = TRUE) are excluded from MRR calculations

## Data Quality Tests

### Generic Tests (12 total)
Implemented in `schema.yml` files using dbt's built-in test types:

1. **Foreign Key Relationships** (4 tests):
   - `raw_subscriptions.account_id` → `raw_accounts.account_id`
   - `raw_feature_usage.subscription_id` → `raw_subscriptions.subscription_id`
   - `raw_support_tickets.account_id` → `raw_accounts.account_id`
   - `raw_churn_events.account_id` → `raw_accounts.account_id`

### Custom Business Logic Tests (1 test)
Implemented in `tests/` folder:

1. **Churn Date Validation**: 
   - Ensures `churn_date` in `churn_events` occurs on or after subscription `end_date`
   - Validates temporal consistency between subscription lifecycle and churn events
   - Located: `tests/test_churn_date_after_subscription_end.sql`

**Total: 13 tests** (exceeds requirement of minimum 5)

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
3. **Trial Handling**: Trials are flagged but not separated in revenue calculations
4. **Currency**: All amounts assumed to be in USD with no currency conversion
5. **Billing Frequency**: Annual subscriptions are converted to MRR (ARR/12) but this may not reflect actual cash collection timing

### Edge Cases Identified

1. **Same-Month Start and End**: Subscriptions that start and end in the same month
2. **Rapid Plan Changes**: Multiple upgrades/downgrades within a single month
3. **Reactivations**: Previously churned accounts returning (flagged in churn_events)
4. **Partial Month Revenue**: Pro-rating for mid-month starts/ends not implemented
5. **Backdated Subscriptions**: Historical data loads where subscription dates precede signup_date

## Production Improvements

### Scalability & Performance
1. **Incremental Models**: Implement incremental materialization for large tables (subscriptions, feature_usage)
   ```sql
   {{ config(materialized='incremental', unique_key='subscription_id') }}
   ```
2. **Partitioning**: Partition large tables by date (year/month) for better query performance
3. **Indexing Strategy**: Add indexes on frequently joined columns (account_id, subscription_id)
4. **Query Optimization**: Use CTEs judiciously, consider materializing complex intermediate calculations

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
   - Use `is_incremental()` macro to filter source data
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
4. **Access Control**: Implement role-based access to sensitive PII data
5. **Backup Strategy**: Regular DuckDB file backups, consider migration to cloud warehouse (Snowflake/BigQuery) for production

## Repository

GitHub: [Link to repository]

## Contact

Mykolas - Analytics Engineer Candidate

---

*This project was completed as part of the Oxylabs Analytics Engineer technical assessment.*