-- Question 10

set statistics io on;

set statistics time on;

-- Original query
SELECT o.customer_id, COUNT(*) AS orders_2024, 
	(SELECT SUM(oi.line_amount) 
	FROM fact_order_items oi 
	JOIN fact_orders o2 ON o2.order_id = oi.order_id 
	WHERE o2.customer_id = o.customer_id) AS lifetime_value 
FROM fact_orders o 
WHERE YEAR(o.order_date) = 2024 
GROUP BY o.customer_id;

-- 1. what the original plan was doing

-- the original query had two main performance issues:
-- - the predicate `year(o.order_date) = 2024` applies a function to
--   `order_date`, making it harder for sql server to efficiently use
--   an index on `order_date`.

-- - the lifetime value was calculated using a correlated subquery,
--   which caused another access to `fact_orders` and `fact_order_items`
--   for the customer-level calculation.

-- baseline performance of the original query:
-- - fact_orders logical reads: 378
-- - fact_order_items logical reads: 267
-- - total logical reads: 645
-- - cpu time: 141 ms
-- - elapsed time: 234 ms

-- Rewritten fast query
select
      o.customer_id
    , count(*) as orders_2024
    , lv.lifetime_value
from dbo.fact_orders o
join (
    select
          o2.customer_id
        , sum(oi.line_amount) as lifetime_value
    from dbo.fact_orders o2
    join dbo.fact_order_items oi
        on o2.order_id = oi.order_id
    group by o2.customer_id
) lv
    on o.customer_id = lv.customer_id
where o.order_date >= '2024-01-01'
  and o.order_date < '2025-01-01'
group by
      o.customer_id
    , lv.lifetime_value;

-- the query was rewritten to:
-- - calculate lifetime value once per customer using a grouped subquery
-- - replace the non-sargable `year(order_date)` filter with a date range

-- performance after rewriting but before indexing:
-- - fact_orders logical reads: 378
-- - fact_order_items logical reads: 267
-- - total logical reads: 645
-- - cpu time: 125 ms
-- - elapsed time: 214 ms

-- the rewrite reduced cpu time and elapsed time slightly,
-- but logical reads remained the same.

-- Creating the index
create index ix_fact_orders_order_date_customer
on dbo.fact_orders (order_date, customer_id);

select
      o.customer_id
    , count(*) as orders_2024
    , lv.lifetime_value
from dbo.fact_orders o
join (
    select
          o2.customer_id
        , sum(oi.line_amount) as lifetime_value
    from dbo.fact_orders o2
    join dbo.fact_order_items oi
        on o2.order_id = oi.order_id
    group by o2.customer_id
) lv
    on o.customer_id = lv.customer_id
where o.order_date >= '2024-01-01'
  and o.order_date < '2025-01-01'
group by
      o.customer_id
    , lv.lifetime_value;

-- the above index was added because `order_date` is used to filter the 2024 orders.

-- after adding the index and running the rewritten query again:
-- - fact_orders logical reads: 227
-- - fact_order_items logical reads: 267
-- - total logical reads: 494
-- - cpu time: 94 ms
-- - elapsed time: 208 ms

-- comparison:

-- original total logical reads: 645
-- after rewrite + index:       494
-- logical reads decreased by approximately 23%.
-- fact_orders logical reads decreased from 378 to 227,
-- which is approximately a 40% reduction.

-- cpu time decreased from 141 ms to 94 ms.

-- the index improved the plan because sql server could use the
-- `order_date` index to access the relevant date range more efficiently,
-- rather than reading as much data from `fact_orders`.

-- the main optimization was therefore making the date predicate
-- sargable and creating an index that supports that predicate.

-- Approach:
-- Analyzed the original query's performance using SET STATISTICS IO
-- and SET STATISTICS TIME. Rewrote the correlated subquery to
-- calculate lifetime value once per customer and replaced the
-- YEAR(order_date) filter with a sargable date range. Added an index
-- on order_date and customer_id to improve access to the filtered
-- fact_orders data. Compared logical reads, CPU time, and elapsed time
-- before and after the optimization.

-- Result:
-- Reduced total logical reads from 645 to 494 and CPU time from
-- 141 ms to 94 ms, while maintaining the same query result.