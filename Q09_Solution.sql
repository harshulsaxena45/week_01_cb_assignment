-- Question 9

select * into dbo.dim_product_q9 from dbo.dim_product;

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

-- Approach:
-- Created a separate copy of dim_product as dim_product_q9 so that
-- the original dim_product table was not modified. Applied the changes
-- from cdc_product_changes using a single MERGE, handling inserts,
-- updates, and deletes based on the operation code. The separate target
-- table was used to compare the original and final data during validation.

-- Result:
-- Returns the updated dim_product_q9 table with all CDC changes applied,
-- while preserving the original dim_product table for validation of
-- inserted, updated, and deleted products.