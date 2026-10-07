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

-- Approach:
-- Grouped completed orders by customer and calendar month to identify
-- the months in which each customer was active. Used ROW_NUMBER() and
-- DATEDIFF() to create a consistent month sequence and identify
-- consecutive-month streaks. Grouped the streaks and selected the
-- longest streak for each customer.

-- Result:
-- Returns each customer's longest consecutive streak of months with
-- at least one completed order.