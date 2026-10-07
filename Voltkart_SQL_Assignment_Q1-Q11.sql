-- use Voltkart;

-- Question 1

select top 20
	  fo.order_id
	, fo.order_date
	, regexp_replace(dc.customer_name, '[0-9]', '') as customer_name
	, de.employee_name as sales_rep_name
	, fo.order_total
from dbo.fact_orders fo
left join dbo.dim_customer dc
	on fo.customer_id = dc.customer_id
left join dbo.dim_employee de
	on fo.sales_rep_id = de.employee_id
where fo.order_status = 'Completed'
order by fo.order_total desc;

-- Question 2

select
	  dc.customer_id
	, regexp_replace(dc.customer_name, '[0-9]', '') as customer_name
	, dc.signup_date
from dbo.dim_customer dc
where not exists (
	select 1
	from dbo.fact_orders fo
	where dc.customer_id = fo.customer_id
);

-- Question 3

with base as (
	select distinct
		  dc.category_name
		, dp.product_name
		, sum(foi.line_amount) over (partition by dp.product_name) as total_revenue
	from dbo.fact_order_items foi
	left join dbo.fact_orders fo
		on foi.order_id = fo.order_id
	left join dbo.dim_product dp
		on foi.product_id = dp.product_id
	left join dbo.dim_category dc
		on dp.category_id = dc.category_id
	where fo.order_status = 'Completed'
)

, rank as (
	select
		  category_name
		, product_name
		, total_revenue
		, rank() over (partition by category_name order by total_revenue desc) as revenue_rank
	from base
)

select
	*
from rank
where revenue_rank <= 3
order by category_name, revenue_rank;

-- Question 4

with base as (
	select
		  format(order_date, 'yyyy-MM') as order_month
		, sum(order_total) as monthly_revenue
	from dbo.fact_orders
	where order_status = 'Completed'
	group by format(order_date, 'yyyy-MM')
)

, calculated_metrics as (
	select
		  order_month
		, monthly_revenue
		, sum(monthly_revenue) over (
			order by order_month
			rows between unbounded preceding and current row
		  ) as running_total
		, lag(monthly_revenue) over (order by order_month) as previous_revenue
	from base
)

select
	  order_month
	, monthly_revenue
	, running_total
	, round(((monthly_revenue - previous_revenue) / previous_revenue) * 100.0, 2) as mom_pct_change
from calculated_metrics;

-- Question 5

with base as (
	select
		  customer_id
		, sum(order_total) as lifetime_completed_spend
	from dbo.fact_orders
	where order_status = 'Completed'
	group by customer_id
)

, calculated_metrics as (
	select
		  customer_id
		, lifetime_completed_spend
		, ntile(4) over (order by lifetime_completed_spend desc) as spend_quartile
	from base
)

select
	  spend_quartile
	, count(*) as customer_count
	, avg(lifetime_completed_spend) as avg_lifetime_spend
from calculated_metrics
group by spend_quartile;

-- Question 6

with category as (
	select
		  category_id
		, category_name
		, 0 as depth_level
		, cast(category_name as varchar(1000)) as category_path
	from dbo.dim_category
	where category_name = 'Computers'

	union all
	
	select
		  c1.category_id
		, c1.category_name
		, c2.depth_level + 1 as depth_level
		, cast(c2.category_path + ' > ' + c1.category_name as varchar(1000)) as category_path
	from dbo.dim_category c1
	join category c2
		on c1.parent_category_id = c2.category_id
)

select
	*
from category
option (maxrecursion 100);

-- Question 7

with base as (
	select
		  sales_rep_id
		, sum(order_total) as total_order_value_generated
	from dbo.fact_orders
	where order_status = 'Completed'
	group by sales_rep_id
)

, manager_details as (
	select
		  de.employee_id
		, de.employee_name
		, de.manager_id
		, de.role
		, b.total_order_value_generated
	from dbo.dim_employee de
	left join base b
		on de.employee_id = b.sales_rep_id
)

, team_total_revenue as (
	select
		  employee_id
		, employee_name
		, role
		, manager_id
		, total_order_value_generated as team_total_revenue
	from manager_details
	where total_order_value_generated is not null

	union all

	select
		  md1.employee_id
		, md1.employee_name
		, md1.role
		, md1.manager_id
		, ttr.team_total_revenue
	from manager_details md1
	join team_total_revenue ttr
		on md1.employee_id = ttr.manager_id
)

select
	  employee_id
	, employee_name
	, role
	, sum(team_total_revenue) as team_total_revenue
from team_total_revenue
group by employee_id, employee_name, role
option (maxrecursion 200);

-- Question 8

-- select * from dbo.stg_orders_incr;

select * into dbo.fact_orders_q8 from dbo.fact_orders;

-- select * from dbo.fact_orders_q8

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

-- Question 9

-- select * from dbo.cdc_product_changes;

select * into dbo.dim_product_q9 from dbo.dim_product;

-- select * from dbo.dim_product_q9;

merge into dbo.dim_product_q9 as target
using dbo.cdc_product_changes as source
	on target.product_id = source.product_id
when matched and source.operation = 'U'
	then update set target.product_name = source.product_name,
					target.category_id = source.category_id,
					target.unit_price = source.unit_price,
					target.unit_cost = source.unit_cost,
					target.launch_date = source.launch_date
when matched and source.operation = 'D'
	then delete
when not matched and source.operation = 'I'
	then insert (product_id, product_name, category_id, unit_price, unit_cost, launch_date)
		 values (source.product_id, source.product_name, source.category_id, source.unit_price, source.unit_cost, source.launch_date);

-- Validation query

-- Row count before vs after
select
      (select count(*) from dbo.dim_product) as original_row_count
    , (select count(*) from dbo.dim_product_q9) as final_row_count
    , (select count(*) from dbo.dim_product_q9)
      - (select count(*) from dbo.dim_product) as net_change;

-- Verify updates
select
      n.product_id
    , o.product_name as old_product_name
    , n.product_name as new_product_name
    , o.category_id as old_category_id
    , n.category_id as new_category_id
    , o.unit_price as old_unit_price
    , n.unit_price as new_unit_price
    , o.unit_cost as old_unit_cost
    , n.unit_cost as new_unit_cost
from dbo.dim_product o
join dbo.dim_product_q9 n
    on o.product_id = n.product_id
where
       o.product_name <> n.product_name
    or o.category_id <> n.category_id
    or o.unit_price <> n.unit_price
    or o.unit_cost <> n.unit_cost
    or o.launch_date <> n.launch_date;

-- Verify inserts
select
      n.*
from dbo.dim_product_q9 n
left join dbo.dim_product o
    on n.product_id = o.product_id
where o.product_id is null;

-- Verify deletes
select
      o.*
from dbo.dim_product o
left join dbo.dim_product_q9 n
    on o.product_id = n.product_id
where n.product_id is null;

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
--
-- the original query had two main performance issues:
--
-- - the predicate `year(o.order_date) = 2024` applies a function to
--   `order_date`, making it harder for sql server to efficiently use
--   an index on `order_date`.
--
-- - the lifetime value was calculated using a correlated subquery,
--   which caused another access to `fact_orders` and `fact_order_items`
--   for the customer-level calculation.
--
-- baseline performance of the original query:
--
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
--
-- - calculate lifetime value once per customer using a grouped subquery
-- - replace the non-sargable `year(order_date)` filter with a date range

-- performance after rewriting but before indexing:
--
-- - fact_orders logical reads: 378
-- - fact_order_items logical reads: 267
-- - total logical reads: 645
-- - cpu time: 125 ms
-- - elapsed time: 214 ms
--
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

-- the above index was added because `order_date` is used
-- to filter the 2024 orders.

-- after adding the index and running the rewritten query again:
--
-- - fact_orders logical reads: 227
-- - fact_order_items logical reads: 267
-- - total logical reads: 494
-- - cpu time: 94 ms
-- - elapsed time: 208 ms
--
-- comparison:
--
-- original total logical reads: 645
-- after rewrite + index:       494
--
-- logical reads decreased by approximately 23%.
--
-- fact_orders logical reads decreased from 378 to 227,
-- which is approximately a 40% reduction.
--
-- cpu time decreased from 141 ms to 94 ms.
--
-- the index improved the plan because sql server could use the
-- `order_date` index to access the relevant date range more efficiently,
-- rather than reading as much data from `fact_orders`.
--
-- the main optimization was therefore making the date predicate
-- sargable and creating an index that supports that predicate.

-- Question 11

with base as (
	select
		  fo.customer_id
		, dc.customer_name
		, cast(format(fo.order_date, 'yyyy-MM') + '-01' as date) as order_month
		, count(*) as total_order_count
	from dbo.fact_orders fo
	left join dbo.dim_customer dc
		on fo.customer_id = dc.customer_id
	where fo.order_status = 'Completed'
	group by fo.customer_id, dc.customer_name, format(fo.order_date, 'yyyy-MM')
)

, calculated_metrics as (
	select
		  *
		, row_number() over (partition by customer_id order by order_month) as order_month_rank
		, datediff(month, '19000101', order_month) as continuous_month_number
		, datediff(month, '19000101', order_month) - row_number() over (partition by customer_id order by order_month) as month_diff
	from base
)

, interim_metrics as (
	select
		  customer_id
		, customer_name
		, month_diff
		, count(*) as streak_months
	from calculated_metrics
	group by customer_id, customer_name, month_diff
)

select
	  customer_id
	, customer_name
	, max(streak_months) as longest_streak_months
from interim_metrics
group by customer_id, customer_name
order by customer_id;
