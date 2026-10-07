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

-- Approach:
-- Used a recursive CTE starting from the 'Computers' category and
-- recursively traversed its child categories through the
-- parent_category_id relationship. Tracked the depth of each category
-- and built a readable category path from the root category.

-- Result:
-- Returns all categories under 'Computers' at any depth, along with
-- their category_id, category_name, depth_level, and category_path.