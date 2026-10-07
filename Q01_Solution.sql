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

-- Approach:
-- Filtered fact_orders to completed orders, then joined it with
-- dim_customer and dim_employee to retrieve customer and sales
-- representative details. Sorted the completed orders by order_total
-- in descending order and selected the top 20 records.

-- Result:
-- Returns the 20 highest-value completed orders along with their
-- order, customer, and sales representative details.