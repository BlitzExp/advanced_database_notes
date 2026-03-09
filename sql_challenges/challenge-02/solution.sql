-- LESSONS 6 7

-- Section 6
    -- Find the domestic and international sales for each movie
SELECT * FROM movies INNER JOIN Boxoffice ON Movies.id = Boxoffice.Movie_id;
    -- Show the sales numbers for each movie that did better internationally rather than domestically
SELECT * FROM movies INNER JOIN Boxoffice ON Movies.id = Boxoffice.Movie_id Where Boxoffice.Domestic_sales < Boxoffice.International_sales;
    -- List all the movies by their ratings in descending order
SELECT * FROM movies INNER JOIN Boxoffice ON Movies.id = Boxoffice.Movie_id ORDER BY Boxoffice.Rating DESC

-- Section 7
    -- Find the list of all buildings that have employees
SELECT DISTINCT Building_name FROM Buildings Inner Join Employees ON Buildings.Building_name = Employees.Building;
    -- Find the list of all buildings and their capacity
SELECT * FROM Buildings
    -- List all buildings and the distinct employee roles in each building (including empty buildings)
SELECT DISTINCT buildings.building_name, employees.role FROM buildings LEFT JOIN employees ON buildings.building_name = employees.building;

-- Interview Question!

    -- Assume you're given two tables containing data about Facebook Pages and their respective likes (as in "Like a Facebook Page").
    --Write a query to return the IDs of the Facebook pages that have zero likes. The output should be sorted in ascending order based on the page IDs.
SELECT DISTINCT p.page_id FROM pages as p LEFT OUTER JOIN page_likes as pl ON p.page_id = pl.page_id WHERE pl.page_id IS NULL ORDER BY p.page_id;