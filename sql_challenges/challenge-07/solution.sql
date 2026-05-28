-- UNION, MINUS, INTERSECT

-- UNION
    -- Complete this query to return a list of all the colours in the two tables. Each colour must only appear once:
select colour from my_brick_collection
union
select colour from your_brick_collection
order by colour;
    -- Complete the following query to return a list of all the shapes in both tables. There must show one row for each row in the source tables:
select shape from my_brick_collection
union all
select shape from your_brick_collection
order  by shape;

-- MINUS + INTERSECT
    -- Complete the following query to return a list of all the shapes in my collection not in yours:
select shape from my_brick_collection
minus
select shape from your_brick_collection;
    -- Complete the following query to return a list of all the colours that are in both tables:
select colour from my_brick_collection
intersect
select colour from your_brick_collection
order  by colour;
