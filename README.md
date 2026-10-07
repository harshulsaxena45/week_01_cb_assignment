# Voltkart SQL Challenge

SQL solutions for the Codebasics DE Bootcamp assignment.

## Overview

This repository contains solutions for Questions 1–11 covering:

- Advanced SQL
- Semi and anti joins
- Window functions
- Recursive CTEs
- Incremental loading
- MERGE
- CDC
- Query optimization
- Execution plans
- Customer retention analysis

## Questions

| Question | Topic |
|---|---|
| Q1 | Top 20 completed orders |
| Q2 | Customers who never ordered |
| Q3 | Top products by category |
| Q4 | Monthly revenue and MoM growth |
| Q5 | Customer spend quartiles |
| Q6 | Recursive category hierarchy |
| Q7 | Recursive team revenue |
| Q8 | Incremental MERGE |
| Q9 | CDC MERGE |
| Q10 | Query optimization |
| Q11 | Customer retention streaks |

## Q10 Optimization

Original total logical reads: 645

Optimized total logical reads: 494

CPU time:
141 ms → 94 ms

The query was optimized by replacing the non-sargable
`YEAR(order_date)` filter with a date range, restructuring the
correlated subquery, and adding an index on `order_date, customer_id`.

## Tools

- SQL Server
- SQL Server Management Studio (SSMS)
- T-SQL
