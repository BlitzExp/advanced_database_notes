-- Section 1
    -- Find the title of each film  
SELECT Title FROM movies;
    -- Find the director of each film
SELECT Director FROM movies;
    -- Find the title and director of each film
SELECT Title, Director FROM movies;
    -- Find the title and year of each film
SELECT Title, Year FROM movies;
    -- Find all the information about each film
SELECT * FROM movies;

-- Section 2
    -- Find the movie with a row id of 6
SELECT * FROM movies WHERE Id = 6;
    -- Find the movies released in the years between 2000 and 2010
SELECT * FROM movies WHERE Year BETWEEN 2000 AND 2010
    -- Find the movies not released in the years between 2000 and 2010
SELECT * FROM movies WHERE Year NOT BETWEEN 2000 AND 2010
    -- Find the first 5 Pixar movies and their release year
SELECT Title, Year FROM movies LIMIT 5

-- Section 3
    -- Find all the Toy Story movies
SELECT * FROM movies WHERE Title Like "%Toy Story%";
    -- Find all the movies directed by John Lasseter
SELECT * FROM movies WHERE Director = "John Lasseter";
    -- Find all the movies (and director) not directed by John Lasseter
SELECT * FROM movies WHERE NOT Director = "John Lasseter";
    -- Find all the WALL-* movies
SELECT * FROM movies WHERE Title Like "WALL-%";}

-- Section 4
    -- List all directors of Pixar movies (alphabetically), without duplicates
SELECT DISTINCT Director FROM movies ORDER BY Director ASC;
    -- List the last four Pixar movies released (ordered from most recent to least)
SELECT * FROM movies ORDER BY YEAR DESC LIMIT 4;
    -- List the first five Pixar movies sorted alphabetically
SELECT * FROM movies ORDER BY TITLE ASC LIMIT 5;
    -- List the next five Pixar movies sorted alphabetically
SELECT * FROM movies ORDER BY TITLE ASC LIMIT 5 OFFSET 5;

-- Section 5
    -- List all the Canadian cities and their populations
SELECT City, Population FROM north_american_cities WHERE Country = "Canada";
    -- Order all the cities in the United States by their latitude from north to south
SELECT * FROM north_american_cities WHERE Country = "United States" ORDER BY Latitude DESC;
    -- List all the cities west of Chicago, ordered from west to east
SELECT * FROM north_american_cities WHERE Longitude < (SELECT Longitude FROM north_american_cities WHERE City = 'Chicago') ORDER BY Longitude ASC;
    -- List the two largest cities in Mexico (by population)
SELECT * FROM north_american_cities WHERE Country = "Mexico" Order by Population DESC Limit 2;
    -- List the third and fourth largest cities (by population) in the United States and their population
SELECT City, Population FROM north_american_cities WHERE Country = "United States" Order by Population DESC Limit 2 OFFSET 2;