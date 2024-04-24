-- Exploring tables

SELECT * FROM order_details;
-- order_details_id, order_id, pizza_id and quantity ordered

SELECT * FROM orders; 
-- order_id, date and time when the order was made 

SELECT * FROM pizza_types;
-- pizza_type_id, name, category and ingredients for the pizza

SELECT * FROM pizzas;
-- pizza_id, pizza_type_id, size and price for the pizza


-- Create a Temporary table containing order information: order_details_id,
-- order_id, pizza_name, size, quantity, date, time, total price
CREATE TEMP TABLE order_info AS
SELECT od.order_details_id, od.order_id, pt.name as pizza_name, p.size, 
od.quantity, o.date as order_date, o.time as order_time,
od.quantity * p.price as pizza_price
FROM orders o
INNER JOIN order_details od ON o.order_id = od.order_id
INNER JOIN pizzas p ON od.pizza_id = p.pizza_id
INNER JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id;

SELECT * FROM order_info;

-- 1. Does the table contain Null values?
SELECT SUM(CASE
		WHEN order_details_id IS NULL THEN 1 ELSE 0 
		END) AS order_details_id_nulls,
	SUM(CASE
		WHEN order_id IS NULL THEN 1 ELSE 0 
		END) AS order_id_nulls,
	SUM(CASE
		WHEN pizza_name IS NULL THEN 1 ELSE 0 
		END) AS pizza_name_nulls,
	SUM(CASE
		WHEN size IS NULL THEN 1 ELSE 0 
		END) AS size_nulls,
	SUM(CASE
		WHEN quantity IS NULL THEN 1 ELSE 0 
		END) AS quantity_nulls,
	SUM(CASE
		WHEN order_date IS NULL THEN 1 ELSE 0 
		END) AS order_date_nulls,
	SUM(CASE
		WHEN order_time IS NULL THEN 1 ELSE 0 
		END) AS order_time_nulls,
	SUM(CASE
		WHEN pizza_price IS NULL THEN 1 ELSE 0 
		END) AS pizza_price_nulls
FROM order_info;
-- We have 0 Null values in order_info temporary table


-- 2. What are the order details and total price for each order?
CREATE TEMP TABLE total_price AS
SELECT order_id, order_date, order_time, SUM(pizza_price) AS total_price, STRING_AGG(pizza_name, ', ') AS details
FROM order_info
GROUP BY 1, 2, 3;

SELECT * FROM total_price;


-- 3. Create bins for total price to analyze order price distribution
SELECT trunc(total_price::decimal, -1) AS total_order_price,
COUNT(order_id) AS orders_count
FROM total_price tp
GROUP BY 1
ORDER BY 1;


-- 4. Define price bins with upper and lower bounds
with bins AS (
	SELECT generate_series(0, 440, 10) as lower,
		   generate_series(10, 450, 10) as upper
),
count_column AS (
	SELECT total_price
	FROM total_price
)
SELECT lower, upper, COUNT(total_price) AS amount
FROM bins
LEFT JOIN count_column ON total_price >= lower AND lower < upper
GROUP BY lower, upper
ORDER BY lower;


-- 5.At what time of day do we see the highest volume of orders?
SELECT date_trunc('hours', order_time) AS hours, 
	   COUNT(order_id) AS amount
FROM total_price
GROUP BY 1
ORDER BY 1;
-- The most amount of order were made between 12:00-13:00
-- and 17:00-19:00


-- 6. On which day of the week do we see the most orders?
SELECT to_char(order_date, 'day') as day_of_week, 
	   COUNT(order_id) AS amount
FROM total_price
GROUP BY 1, EXTRACT(DOW FROM order_date)
ORDER BY EXTRACT(DOW FROM order_date);
-- The most amount of orders were made on friday


-- 7. What kind of pizzas do people order the most?
SELECT pizza_name, SUM(quantity) AS amount_ordered
FROM order_info
GROUP BY 1
ORDER BY 2 DESC;

-- 8. What kind of pizzas has made the most amount of money?
SELECT pizza_name, SUM(pizza_price) as total_price
FROM order_info
GROUP BY 1
ORDER BY 2 DESC;

-- 9. What are the most popular pizza sizes?
SELECT size, SUM(quantity) as amount_ordered
FROM order_info
GROUP BY 1
ORDER BY 2 DESC;

-- 10. What is the max, min, average and median order price?
SELECT ROUND(MAX(total_price)::DECIMAL, 2) AS max_order_price,
	   ROUND(MIN(total_price)::DECIMAL, 2) AS min_order_price,
	   ROUND(AVG(total_price)::DECIMAL, 2) AS avg_order_price,
	   percentile_cont(0.5) WITHIN GROUP (ORDER BY total_price) AS median_price
FROM total_price;


-- 11. What are the most popular ingredients?
-- Creating rows from list of ingredients and counting each one
SELECT TRIM(unnest(string_to_array(sub.ingredients, ','))) AS ingredients, COUNT(*) AS ingredient_count 
FROM(
	SELECT oi.*, pt.ingredients -- For each ordered pizza we add pizza's ingredients
	FROM order_info oi 
	INNER JOIN pizza_types pt ON oi.pizza_name = pt.name
) AS sub
GROUP BY 1
ORDER BY 2 DESC;
-- In total we have 65 different ingredients
-- Wow, the most popular ingredient here is Garlic


-- 12. What is most popular pizza for each day of the week?
with cte_1 AS (
	SELECT to_char(order_date, 'day') as day_of_week, 
		   pizza_name, 
		   SUM(quantity) as amount_ordered,
		   ROW_NUMBER() OVER (PARTITION BY EXTRACT(DOW FROM order_date) ORDER BY SUM(quantity) DESC) AS rank
	FROM order_info
	GROUP BY 1, EXTRACT(DOW FROM order_date), 2
)
SELECT day_of_week, pizza_name, amount_ordered
FROM cte_1
WHERE rank = 1;


-- 13. What is the amount of orders made each season (spring, summer, autumn, winter)?
with spring AS (
	SELECT 'Spring' AS season, SUM(quantity) as amount_ordered
	FROM order_info
	WHERE order_date BETWEEN '2015-03-01' AND '2015-05-31'
),
summer AS (
	SELECT 'Summer' AS season, SUM(quantity) as amount_ordered
	FROM order_info
	WHERE order_date BETWEEN '2015-06-01' AND '2015-08-31'
),
autumn AS (
	SELECT 'Autumn' AS season, SUM(quantity) as amount_ordered
	FROM order_info
	WHERE order_date BETWEEN '2015-09-01' AND '2015-11-30'
),
winter AS (
	SELECT 'Winter' AS season, SUM(quantity) as amount_ordered
	FROM order_info
	WHERE order_date BETWEEN '2015-12-01' AND '2015-12-31' or order_date BETWEEN '2015-01-01' AND '2015-02-28'
)
SELECT * FROM spring
UNION ALL
SELECT * FROM summer
UNION ALL
SELECT * FROM autumn
UNION ALL
SELECT * FROM winter;


-- 14. What was the date when first 10.000 orders were made from the start of the year?
with cte_1 AS (
	SELECT order_date,
		   SUM(quantity) OVER (ORDER BY order_date) AS amount_ordered
	FROM order_info
)
SELECT order_date, amount_ordered
FROM cte_1
WHERE amount_ordered BETWEEN 9900 AND 10200
GROUP BY order_date, amount_ordered
ORDER BY amount_ordered DESC;
-- It was between 2015-03-13 and 2015-03-14




