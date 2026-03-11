-- Section 10
        -- Find the longest time that an employee has been at the studio
SELECT MAX(years_employed) FROM employees;
        -- For each role, find the average number of years employed by employees in that role
SELECT AVG(years_employed), role FROM employees GROUP BY role;
        -- Find the total number of employee years worked in each building
SELECT building, SUM(years_employed) FROM employees GROUP BY building;

-- Section 11
        -- Find the number of Artists in the studio (without a HAVING clause)
SELECT COUNT(role) FROM employees where role = 'Artist';
        -- Find the number of Employees of each role in the studio
SELECT role, COUNT(role) FROM employees GROUP By role;

-- Find the total number of years employed by all Engineers

SELECT role, SUM(Years_employed)
FROM employees
Where role = 'Engineer';


-- Complete the following query to return the: Number of different shapes and The standard deviation (stddev) of the unique weights
SELECT COUNT(DISTINCT shape) number_of_shapes,
        STDDEV(UNIQUE WEIGHT) distinct_weight_stddev
FROM bricks;

-- Complete the following query to return the total weight for each shape stored in the bricks table:

SELECT shape, SUM(WEIGHT) AS shape_weight
FROM bricks
GROUP BY shape;

-- Complete the following query to find the shapes which have a total weight less than four:

SELECT shape, SUM(WEIGHT) AS sw
FROM bricks
GROUP BY shape
HAVING sw < 4;