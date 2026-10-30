# Berealty Real Estate Property Management Database

A MySQL database for Berealty, a fictional Berlin real estate agency. It manages properties (residential and commercial), clients, agents, viewings and sales transactions, and includes constraints, sample data, triggers, stored procedures and 34 reporting queries.


## How to run
Requires **MySQL 8.0.16 or later**. Run the scripts in this order, in MySQL Workbench:

| Order | File | Purpose |
|---|---|---|
| 1 | `sql/01_schema.sql` | Creates the database, 9 tables, constraints and indexes (drops and recreates `berealty`) |
| 2 | `sql/02_sample_data.sql` | Loads fictional sample data |
| 3 | `sql/03_views_triggers_procedures.sql` | 2 views, 5 triggers, 4 stored procedures |
| 4 | `sql/04_queries.sql` | 34 queries: property search, agents, clients, history, monthly/quarterly/yearly reports, advanced analytics |
| 5 | `sql/05_tests.sql` | Tests for triggers, procedures and constraints (changes data; re-run 1 to 3 to reset) |

## Design highlights
- A client has no fixed role: buyer and seller are roles within a transaction.
- Ownership is explicit: completing a sale marks the property *Sold* and transfers ownership to the buyer.
- Commission is derived: each transaction stores its rate, and the amount is a generated column.
- Rules live in the database: CHECK constraints, foreign keys and triggers prevent invalid data.

## Automation
- **Triggers** validate each transaction, update the property status when a sale is completed or cancelled, keep an audit log, and record price changes.
- **Stored procedures** register offers (locking the property so it cannot be double-sold), close transactions, relist properties and produce a yearly agent report.

## Queries
Joins (INNER, LEFT, RIGHT, CROSS), subqueries, CTEs and window functions (`RANK`, `LAG`, `ROW_NUMBER`, running totals) cover property search, agent performance, client history and periodic reports.

All people, addresses and e-mails in the sample data are fictional.