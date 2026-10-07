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

-- Approach:
-- Aggregated completed order value for each customer to calculate
-- lifetime spend, then used NTILE(4) to divide customers into four
-- quartiles based on their lifetime completed spend. Finally,
-- calculated the customer count and average spend for each quartile.

-- Result:
-- Returns each spend quartile with the number of customers and their
-- average lifetime completed spend.