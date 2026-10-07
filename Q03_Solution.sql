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

-- Approach:
-- Joined fact_order_items with fact_orders, dim_product, and
-- dim_category to calculate completed revenue for each product.
-- Used a window function to calculate product-level revenue and
-- RANK() within each category to identify the top-performing products.

-- Result:
-- Returns the top 3 products in each category based on completed
-- revenue, along with their revenue rank.