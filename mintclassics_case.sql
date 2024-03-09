/*

WAREHOUSE INVENTORY OPTIMIZATION
MINT CLASSICS 
 (3/3/2024)

Business task: examine all tables and identify criteria for reorganization and invetory reduction process not to lose customers and profit
Approach: anaylize customers and specific orders they have placed, and warehouse inventory to solve business task.
Tools: MySQL workbench
Skils: Joins, Aggregations, Temporary tables

*/

-- SUMMARY STATISTICS
-- 1. CUSTOMERS
-- Customer demographics - identify how many unique customers are in each counrty

SELECT country,
	COUNT(DISTINCT(customerNumber)) AS count
	FROM mintclassics.customers
GROUP BY country
ORDER BY count DESC
;



-- Identify what customers order the most / spent the most amount of money
-- Create temporary table to summarize customers activity 

CREATE TEMPORARY TABLE customer_orders
SELECT 	customers.customerNumber,
		customers.customerName,
        customers.city,
        customers.state,
        customers.country,
        orders.orderNumber,
        orders.orderDate,
        orders.shippedDate,
        orders.status        
FROM customers
RIGHT JOIN orders ON customers.customerNumber = orders.customerNumber
;

-- Check created table
SELECT *
FROM customer_orders
;



-- TOP 10 countries that placed the most orders 

SELECT DISTINCT(country),
        COUNT(DISTINCT(orderNumber)) AS number_of_orders
FROM customer_orders
GROUP BY country 
ORDER BY number_of_orders DESC
LIMIT 10
;



-- TOP 10 customers that have placed the most orders 

SELECT DISTINCT(customerName),
        COUNT(DISTINCT(orderNumber)) AS number_of_orders
FROM customer_orders
GROUP BY customerName
ORDER BY number_of_orders DESC
LIMIT 10
;


-- Now we want to know what customers have spent the most money 
-- To solve this task we need to combine 'customer_orders' and 'product_orders' where primary key is 'orderNumber'

CREATE TEMPORARY TABLE customer_summary
SELECT customer_orders.customerNumber,
		customer_orders.customerName,
        customer_orders.city,
        customer_orders.state,
        customer_orders.country,
        customer_orders.orderNumber,
        customer_orders.orderDate,
        customer_orders.shippedDate,
        customer_orders.status,    
		product_orders.productCode,
        product_orders.productName,
        product_orders.productLine,
        product_orders.quantityOrdered,
        product_orders.priceEach,
        product_orders.warehouse
FROM customer_orders
RIGHT JOIN product_orders ON customer_orders.orderNumber = product_orders.orderNumber
;

SELECT *
FROM customer_summary
ORDER BY customerName
;



-- TOP 10 countries that spent the most money on orders

SELECT DISTINCT(country),
		SUM(DISTINCT(quantityOrdered) * priceEach) AS total_sum
FROM customer_summary
GROUP BY country
ORDER BY total_sum DESC
LIMIT 10
;



-- TOP 10 customers that buy (order) the most

SELECT DISTINCT(customerName),
		SUM(DISTINCT(quantityOrdered) * priceEach) AS total_sum
FROM customer_summary
GROUP BY customerName
ORDER BY total_sum DESC
LIMIT 10
;



-- TOP 10 most sold products (by item count) 
SELECT productName,
		SUM(quantityOrdered) AS total
FROM customer_summary
GROUP BY productName
ORDER BY total DESC
LIMIT 10
;



-- Rank product-lines by sale factor  

SELECT productLine,
		SUM(quantityOrdered) AS total_ordered_items
FROM customer_summary
GROUP BY productLine
ORDER BY total_ordered_items DESC
;



-- 2. WAREHOUSE PERFORMANCE 
-- Now that we got to know the customers we would like to identify which warehouse is the most profitable.
-- Find out how many odrers is each warehouse dealing with.
-- To explore each warehouse performance we create a temporary table 'product_orders' with specific columns from 'orderDetails' and 'products' we need for analysis.

CREATE TEMPORARY TABLE product_orders
SELECT 	orderdetails.orderNumber,
		orderdetails.productCode,
        products.productName,
        products.productLine,
		orderdetails.quantityOrdered,
        orderdetails.priceEach,
		products.quantityInStock,
        products.warehouseCode AS warehouse,
        products.buyPrice,
        products.MSRP
FROM mintclassics.orderdetails
RIGHT JOIN mintclassics.products ON orderdetails.productCode = products.productCode
;

SELECT *
FROM product_orders
ORDER BY quantityOrdered DESC
;


-- First, we want to find out what item is not sold and can be get rid off

SELECT *
FROM product_orders
WHERE quantityOrdered IS NULL
;

-- It is product = S18_3233 Totyota Supra is not sold
-- We can get rid of it (quantity in stock 7733 items worth of 440,858.33) this is warehouse B that will free the space



-- Next want to check how many products does each warehouse store and how many have been ordered?
-- We created another temporary table 'wh_invenroty' with warehouse totals
-- Warehouse B has the most products! And warehouse D has the least

CREATE TEMPORARY TABLE wh_inventory
SELECT warehouseCode, 
	SUM(DISTINCT(products.quantityInStock)) AS items_in_stock,
        SUM(product_orders.quantityOrdered) AS items_ordered,
        COUNT(DISTINCT(orderNumber)) AS total_orders,
        SUM(quantityOrdered * priceEach) AS total_order_price
FROM mintclassics.products
RIGHT JOIN product_orders ON products.productCode = product_orders.productCode
GROUP BY warehouseCode
HAVING warehouseCode IS NOT NULL
;

SELECT *
FROM wh_inventory
;


-- Adding other metrics.
-- Here we combining two tables to summarize warehouses different parameters in order to see which warehouse can be reorganized.

SELECT  warehouses.warehouseCode AS warehouse,
	warehouses.warehouseName AS warehouse_name,
        warehouses.warehousePctCap AS warehouse_capacity_pct,
        wh_inventory.items_in_stock AS items_stored,
        items_ordered,
        ROUND(((wh_inventory.items_in_stock / warehouses.warehousePctCap) * 100), 0) AS max_storage_space_items,
	(ROUND(((wh_inventory.items_in_stock / warehouses.warehousePctCap) * 100), 0)) - wh_inventory.items_in_stock AS space_available_items,
        wh_inventory.total_order_price,
        wh_inventory.total_orders
FROM warehouses
RIGHT JOIN wh_inventory ON  warehouses.warehouseCode = wh_inventory.warehouseCode
ORDER BY warehouse
;

-- Also we want analyze processing time of orders, and see which order took the longest time to process
-- Processing time is defimned by time between the day order was placed and shipping date.alter

SELECT productName,
		productLine,
        orderNumber,
        quantityOrdered,
        status,
        DATEDIFF(shippedDate, orderDate) as processing_time,
        warehouse
FROM customer_summary
ORDER BY processing_time DESC, warehouse
;

-- Calculating summary of processing times for each warehouse.

SELECT warehouse,
        AVG(DATEDIFF(shippedDate, orderDate)) as avg_processing_time,
		MIN(DATEDIFF(shippedDate, orderDate)) as min_processing_time,
		MAX(DATEDIFF(shippedDate, orderDate)) as max_processing_time
FROM customer_summary
GROUP BY warehouse
;

-- The largest warehouse is warehouse B and its 67% full.
-- The smallest is D, it is 75% full, and it sold the least amount of items with one of the longest processing times along with warehouse B 
-- So we recommend to reconsolidate 79380 items from warehouse D to other warehouses



-- 3. EXPLORING WAREHOUSE D
-- How to reorganize these items and into which warehouse?
-- What items are stored in warehouse d?
-- What orders / customer-products shipped from it?


-- In order to move items from warehouse D check what product-line does each warehouse have, that will help to properly reconsdolidate items
-- What productLine products are stored in warehouse D?

SELECT DISTINCT(productLine)
FROM product_orders
WHERE warehouse = 'd'
;

-- Warehouse D stored 'Trucks and Buses, Ships, Trains' productLine items

-- How many items are stored in each productLine in warehouse D?

SELECT DISTINCT(productLine),
		SUM(DISTINCT(quantityInStock)) as total_items
 FROM product_orders
 WHERE warehouse  = 'd'
 GROUP BY productLine
;



-- Identify which orders contain warehouse D productLine items and also have items ordered from other warehouses
-- The most expensive order of warehouse D and total items ordered

SELECT  DISTINCT(orderNumber),
        SUM(quantityOrdered * priceEach) AS total_order_price,
        SUM(quantityOrdered) AS total_items_ordred
FROM product_orders
WHERE warehouse = 'd'
GROUP BY orderNumber
ORDER BY total_order_price DESC
LIMIT 10
;



-- FILTER BY ORDER_NUMBER - all orderds with productLine, quantity and warehouse
-- We manually entered first 10 most expensive orders to check what other warehouse they ship their products from

SELECT  DISTINCT(orderNumber),
		productLine,
        quantityOrdered,
        warehouse
FROM product_orders
WHERE orderNumber = 10207
ORDER BY orderNumber
;


-- Conclusion.
-- Upon invetigating inventory and specifics of customer orders we can recommend to close warehouse D (South) and redistribute its items into warehouse B since most of the customers who ordered products from warehouse D were also ordering products from warehouse B. 
-- Additionally, warehouse B has adequate available space.
-- Another option can be to redistribute items from warehouse D into B and C warehouses. 
-- But further examination of order specifics is required to determine which product lines need to be move to which warehouse.
-- We do not recommend redistribute items from warehouse D to warehpuse A - it doesn't have enough space.
