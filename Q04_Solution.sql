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

-- Approach:
-- Grouped completed orders by month to calculate monthly revenue.
-- Used a window function with an explicit ROWS frame to calculate
-- the cumulative running total, and LAG() to retrieve the previous
-- month's revenue for calculating the month-over-month percentage change.

-- Result:
-- Returns monthly completed revenue, cumulative running revenue,
-- and the month-over-month revenue change percentage.