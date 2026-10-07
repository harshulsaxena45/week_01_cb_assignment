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

-- Approach:
-- Used an anti join with NOT EXISTS to identify customers who have
-- no matching records in fact_orders. Joined dim_customer only to
-- retrieve the required customer details and signup date.

-- Result:
-- Returns customers who have never placed an order, along with their
-- customer_id, customer_name, and signup_date.