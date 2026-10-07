-- Question 8

select * into dbo.fact_orders_q8 from dbo.fact_orders;

merge into dbo.fact_orders_q8 as target
using dbo.stg_orders_incr as source
	on target.order_id = source.order_id
when matched and (target.order_date <> source.order_date
			 or	  target.customer_id <> source.customer_id
			 or   target.sales_rep_id <> source.sales_rep_id
			 or   target.order_status <> source.order_status
			 or	  target.order_total <> source.order_total)
	then update set target.order_date = source.order_date,
					target.customer_id = source.customer_id,
					target.sales_rep_id = source.sales_rep_id,
					target.order_status = source.order_status,
					target.order_total = source.order_total
when not matched
	then insert (order_id, order_date, customer_id, sales_rep_id, order_status, order_total)
		 values (source.order_id, source.order_date, source.customer_id, source.sales_rep_id, source.order_status, source.order_total);

-- Validation query

-- Row count before vs after
select
      (select count(*) from dbo.fact_orders) as original_row_count
    , (select count(*) from dbo.fact_orders_q8) as final_row_count
    , (select count(*) from dbo.fact_orders_q8)
      - (select count(*) from dbo.fact_orders) as rows_added;

-- Verify updated rows
select
      q.order_id
    , f.order_status as old_status
    , q.order_status as new_status
    , f.order_total as old_order_total
    , q.order_total as new_order_total
    , f.order_date as old_order_date
    , q.order_date as new_order_date
from dbo.fact_orders f
join dbo.fact_orders_q8 q
    on f.order_id = q.order_id
where
       f.order_date <> q.order_date
    or f.customer_id <> q.customer_id
    or f.sales_rep_id <> q.sales_rep_id
    or f.order_status <> q.order_status
    or f.order_total <> q.order_total;

-- Approach:
-- Created a separate copy of fact_orders as fact_orders_q8 so that
-- the original fact_orders table was not modified. Applied the
-- incremental changes from stg_orders_incr using a single MERGE,
-- updating existing orders where values changed and inserting new
-- orders. The separate target table was used to compare the original
-- and final data during validation.

-- Result:
-- Returns the updated fact_orders_q8 table with the incremental
-- changes applied, while preserving the original fact_orders table
-- for before-versus-after validation.