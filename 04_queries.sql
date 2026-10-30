-- =====================================================================
-- File 4 of 5: query library (MySQL 8.0)
-- Sections: A properties | B agents | C clients | D management | E history and reports | F advanced analytics
-- These queries only read data, except section D, which is wrapped in a transaction and rolled back.
-- =====================================================================
USE berealty;

-- =====================================================================
-- A. PROPERTY INFORMATION
-- =====================================================================

-- A1. Available properties, most expensive first (uses the view)
SELECT property_id, type_name, district_name, street_address, bedrooms, area_sqm, asking_price, price_per_sqm
FROM v_available_properties
ORDER BY asking_price DESC;

-- A2. Property search: available residential properties with 2 or 3 bedrooms up to 600,000 EUR
SELECT property_id, type_name, district_name, bedrooms, area_sqm, asking_price
FROM v_available_properties
WHERE segment = 'Residential'
  AND bedrooms BETWEEN 2 AND 3
  AND asking_price <= 600000
ORDER BY price_per_sqm;

-- A3. LEFT JOIN: properties that have never been viewed
SELECT p.property_id, pt.type_name, p.street_address, p.status, p.listing_date
FROM properties p
JOIN property_types pt ON pt.type_id = p.type_id
LEFT JOIN property_viewings pv ON pv.property_id = p.property_id
WHERE pv.viewing_id IS NULL
ORDER BY p.listing_date;

-- A4. RIGHT JOIN: property types with the number of properties (including types with none)
SELECT pt.type_name, pt.segment, COUNT(p.property_id) AS properties
FROM properties p
RIGHT JOIN property_types pt ON pt.type_id = p.type_id
GROUP BY pt.type_id, pt.type_name, pt.segment
ORDER BY properties DESC, pt.type_name;

-- A5. Properties by status and segment
SELECT pt.segment, p.status, COUNT(*) AS properties, ROUND(AVG(p.asking_price), 0) AS avg_asking_price
FROM properties p
JOIN property_types pt ON pt.type_id = p.type_id
GROUP BY pt.segment, p.status
ORDER BY pt.segment, p.status;

-- =====================================================================
-- B. AGENTS AND THE TRANSACTIONS THEY HANDLE
-- =====================================================================

-- B1. Completed sales per agent in 2024, including agents with no sales.
-- The status and date filters are in the ON clause: putting them in WHERE would silently drop agents with no sales.
SELECT a.agent_id,
       CONCAT(a.first_name, ' ', a.last_name) AS agent,
       COUNT(t.transaction_id)                AS completed_sales,
       COALESCE(SUM(t.sale_price), 0)         AS total_sales,
       COALESCE(SUM(t.commission_amount), 0)  AS total_commission
FROM agents a
LEFT JOIN transactions t
       ON t.agent_id = a.agent_id
      AND t.status = 'Completed'
      AND t.transaction_date >= '2024-01-01'
      AND t.transaction_date <  '2025-01-01'
GROUP BY a.agent_id, a.first_name, a.last_name
ORDER BY total_sales DESC;

-- B2. Agent workload: viewings handled against completed sales (separate subqueries avoid double counting)
SELECT a.agent_id,
       CONCAT(a.first_name, ' ', a.last_name) AS agent,
       COALESCE(v.viewings, 0)                AS viewings,
       COALESCE(s.sales, 0)                   AS completed_sales,
       ROUND(COALESCE(s.sales, 0) / NULLIF(v.viewings, 0), 2) AS sales_per_viewing
FROM agents a
LEFT JOIN (SELECT agent_id, COUNT(*) AS viewings
           FROM property_viewings GROUP BY agent_id) v ON v.agent_id = a.agent_id
LEFT JOIN (SELECT agent_id, COUNT(*) AS sales
           FROM transactions WHERE status = 'Completed' GROUP BY agent_id) s ON s.agent_id = a.agent_id
ORDER BY completed_sales DESC, viewings DESC;

-- B3. CTE and window functions: agent ranking, share of revenue and running total
WITH agent_revenue AS (
    SELECT agent_id,
           COUNT(*)               AS deals,
           SUM(sale_price)        AS revenue,
           SUM(commission_amount) AS commission
    FROM transactions
    WHERE status = 'Completed'
    GROUP BY agent_id
)
SELECT CONCAT(a.first_name, ' ', a.last_name) AS agent,
       ar.deals,
       ar.revenue,
       ar.commission,
       RANK() OVER (ORDER BY ar.revenue DESC)                          AS revenue_rank,
       ROUND(100 * ar.revenue / SUM(ar.revenue) OVER (), 1)            AS pct_of_total_revenue,
       SUM(ar.revenue) OVER (ORDER BY ar.revenue DESC
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM agent_revenue ar
JOIN agents a ON a.agent_id = ar.agent_id
ORDER BY revenue_rank;

-- B4. Open pipeline: expected commission from pending transactions
SELECT CONCAT(a.first_name, ' ', a.last_name) AS agent,
       COUNT(*)                AS pending_deals,
       SUM(t.sale_price)       AS pipeline_value,
       SUM(t.commission_amount) AS expected_commission
FROM transactions t
JOIN agents a ON a.agent_id = t.agent_id
WHERE t.status = 'Pending'
GROUP BY a.agent_id, a.first_name, a.last_name
ORDER BY pipeline_value DESC;

-- B5. CROSS JOIN: every agent against every segment, with completed deals (0 where none)
SELECT CONCAT(a.first_name, ' ', a.last_name) AS agent,
       sg.segment,
       COALESCE(x.deals, 0)   AS completed_deals,
       COALESCE(x.revenue, 0) AS revenue
FROM agents a
CROSS JOIN (SELECT DISTINCT segment FROM property_types) sg
LEFT JOIN (SELECT t.agent_id, pt.segment, COUNT(*) AS deals, SUM(t.sale_price) AS revenue
           FROM transactions t
           JOIN properties p      ON p.property_id = t.property_id
           JOIN property_types pt ON pt.type_id = p.type_id
           WHERE t.status = 'Completed'
           GROUP BY t.agent_id, pt.segment) x
       ON x.agent_id = a.agent_id AND x.segment = sg.segment
ORDER BY agent, sg.segment;

-- =====================================================================
-- C. CLIENTS
-- =====================================================================

-- C1. Transaction history of one client (change 12 to any client_id), as buyer or seller
SELECT t.transaction_id,
       t.transaction_date,
       CASE WHEN t.buyer_id = 12 THEN 'Buyer' ELSE 'Seller' END AS client_role,
       p.street_address,
       pt.type_name,
       t.sale_price,
       t.status
FROM transactions t
JOIN properties p      ON p.property_id = t.property_id
JOIN property_types pt ON pt.type_id = p.type_id
WHERE t.buyer_id = 12 OR t.seller_id = 12
ORDER BY t.transaction_date;

-- C2. Every client with properties owned, purchases and sales (LEFT JOINs on aggregated subqueries)
SELECT c.client_id,
       CONCAT(c.first_name, ' ', c.last_name) AS client,
       COALESCE(o.owned, 0)     AS properties_owned,
       COALESCE(b.bought, 0)    AS completed_purchases,
       COALESCE(s.sold, 0)      AS completed_sales
FROM clients c
LEFT JOIN (SELECT owner_id, COUNT(*) AS owned FROM properties GROUP BY owner_id) o ON o.owner_id = c.client_id
LEFT JOIN (SELECT buyer_id, COUNT(*) AS bought FROM transactions WHERE status = 'Completed' GROUP BY buyer_id) b ON b.buyer_id = c.client_id
LEFT JOIN (SELECT seller_id, COUNT(*) AS sold FROM transactions WHERE status = 'Completed' GROUP BY seller_id) s ON s.seller_id = c.client_id
ORDER BY properties_owned DESC, client;

-- C3. Subquery (NOT EXISTS): clients who viewed 2+ properties but have never completed a purchase
SELECT c.client_id,
       CONCAT(c.first_name, ' ', c.last_name) AS client,
       COUNT(*)                               AS viewings,
       ROUND(AVG(pv.interest_level), 1)       AS avg_interest
FROM clients c
JOIN property_viewings pv ON pv.client_id = c.client_id
WHERE NOT EXISTS (SELECT 1 FROM transactions t
                  WHERE t.buyer_id = c.client_id AND t.status = 'Completed')
GROUP BY c.client_id, c.first_name, c.last_name
HAVING COUNT(*) >= 2
ORDER BY viewings DESC, avg_interest DESC;

-- C4. Total value bought and sold per client (clients with completed deals only)
SELECT client,
       SUM(bought_value) AS total_bought,
       SUM(sold_value)   AS total_sold
FROM (
    SELECT CONCAT(c.first_name, ' ', c.last_name) AS client, t.sale_price AS bought_value, 0 AS sold_value
    FROM transactions t JOIN clients c ON c.client_id = t.buyer_id WHERE t.status = 'Completed'
    UNION ALL
    SELECT CONCAT(c.first_name, ' ', c.last_name), 0, t.sale_price
    FROM transactions t JOIN clients c ON c.client_id = t.seller_id WHERE t.status = 'Completed'
) movements
GROUP BY client
ORDER BY total_bought + total_sold DESC;

-- =====================================================================
-- D. MANAGEMENT OPERATIONS (run inside a transaction and rolled back so the data is unchanged)
-- =====================================================================
START TRANSACTION;

-- D1. Register a new client
INSERT INTO clients (first_name, last_name, email, phone, registration_date)
VALUES ('Greta', 'Winter', 'greta.winter@mail.example', '+49 151 555 0217', '2024-10-20');

-- D2. List a new property for that client
INSERT INTO properties (type_id, district_id, owner_id, street_address, postal_code, bedrooms, bathrooms,
                        area_sqm, asking_price, status, listing_date)
VALUES (1, 6, LAST_INSERT_ID(), 'Probeufer 8', '10827', 2, 1, 61.00, 429000.00, 'Available', '2024-10-21');

-- D3. Reduce the asking price (the trigger records it in property_price_history)
UPDATE properties SET asking_price = 419000.00 WHERE street_address = 'Probeufer 8';
SELECT property_id, old_price, new_price FROM property_price_history ORDER BY history_id DESC LIMIT 1;

-- D4. Change an agent's base commission rate
UPDATE agents SET base_commission_rate = 0.0310 WHERE agent_id = 1;

-- D5. Deactivate an agent instead of deleting (history stays intact)
UPDATE agents SET is_active = FALSE WHERE agent_id = 6;

-- D6. Delete a record entered by mistake (clients and properties with history cannot be deleted: the foreign keys protect them)
INSERT INTO property_viewings (property_id, client_id, agent_id, viewing_datetime, feedback, interest_level)
VALUES (5, 1, 4, '2024-10-22 10:00:00', 'Logged by mistake', 1);
DELETE FROM property_viewings WHERE feedback = 'Logged by mistake';

ROLLBACK;

-- =====================================================================
-- E. TRANSACTION HISTORY AND PERIODIC REPORTS
-- =====================================================================

-- E1. Full transaction ledger with all parties (INNER JOINs over seven tables)
SELECT t.transaction_id, t.transaction_date, t.status,
       p.street_address, pt.type_name, d.district_name,
       CONCAT(s.first_name, ' ', s.last_name) AS seller,
       CONCAT(b.first_name, ' ', b.last_name) AS buyer,
       CONCAT(a.first_name, ' ', a.last_name) AS agent,
       t.sale_price, t.commission_amount
FROM transactions t
JOIN properties p      ON p.property_id = t.property_id
JOIN property_types pt ON pt.type_id = p.type_id
JOIN districts d       ON d.district_id = p.district_id
JOIN clients s         ON s.client_id = t.seller_id
JOIN clients b         ON b.client_id = t.buyer_id
JOIN agents a          ON a.agent_id = t.agent_id
ORDER BY t.transaction_date;

-- E2. Ownership and price history of a property with LAG (property 3 was sold twice)
WITH sales AS (
    SELECT t.property_id, t.transaction_date, t.sale_price,
           CONCAT(s.first_name, ' ', s.last_name) AS seller,
           CONCAT(b.first_name, ' ', b.last_name) AS buyer,
           LAG(t.sale_price) OVER (PARTITION BY t.property_id ORDER BY t.transaction_date) AS previous_price
    FROM transactions t
    JOIN clients s ON s.client_id = t.seller_id
    JOIN clients b ON b.client_id = t.buyer_id
    WHERE t.status = 'Completed'
)
SELECT property_id, transaction_date, seller, buyer, sale_price, previous_price,
       ROUND(100 * (sale_price - previous_price) / previous_price, 1) AS pct_change
FROM sales
WHERE property_id = 3
ORDER BY transaction_date;

-- E3. Monthly report, with change against the previous month that had sales
WITH monthly AS (
    SELECT DATE_FORMAT(transaction_date, '%Y-%m') AS ym,
           COUNT(*)               AS deals,
           SUM(sale_price)        AS revenue,
           SUM(commission_amount) AS commission
    FROM transactions
    WHERE status = 'Completed'
    GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
)
SELECT ym AS month, deals, revenue, commission,
       LAG(revenue) OVER (ORDER BY ym) AS previous_month_revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY ym)) / LAG(revenue) OVER (ORDER BY ym), 1) AS pct_change
FROM monthly
ORDER BY ym;

-- E4. Quarterly report with each quarter's share of its year
WITH completed AS (
    SELECT YEAR(transaction_date) AS yr, QUARTER(transaction_date) AS qtr, sale_price, commission_amount
    FROM transactions
    WHERE status = 'Completed'
)
SELECT yr AS year, qtr AS quarter,
       COUNT(*)               AS deals,
       SUM(sale_price)        AS revenue,
       SUM(commission_amount) AS commission,
       ROUND(100 * SUM(sale_price) / SUM(SUM(sale_price)) OVER (PARTITION BY yr), 1) AS pct_of_year
FROM completed
GROUP BY yr, qtr
ORDER BY yr, qtr;

-- E5. Yearly report by segment, with year-on-year growth
WITH completed AS (
    SELECT YEAR(transaction_date) AS yr, sale_price, commission_amount, pt.segment
    FROM transactions t
    JOIN properties p      ON p.property_id = t.property_id
    JOIN property_types pt ON pt.type_id = p.type_id
    WHERE t.status = 'Completed'
),
yearly AS (
    SELECT yr,
           COUNT(*)                                                    AS deals,
           SUM(sale_price)                                             AS revenue,
           ROUND(AVG(sale_price), 0)                                   AS avg_price,
           SUM(commission_amount)                                      AS commission,
           SUM(CASE WHEN segment = 'Residential' THEN sale_price ELSE 0 END) AS residential_revenue,
           SUM(CASE WHEN segment = 'Commercial'  THEN sale_price ELSE 0 END) AS commercial_revenue
    FROM completed
    GROUP BY yr
)
SELECT yr AS year, deals, revenue, avg_price, commission, residential_revenue, commercial_revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY yr)) / LAG(revenue) OVER (ORDER BY yr), 1) AS yoy_growth_pct
FROM yearly
ORDER BY yr;

-- E6. Revenue by district and year (conditional aggregation as a pivot)
SELECT d.district_name,
       SUM(CASE WHEN t.transaction_date >= '2023-01-01' AND t.transaction_date < '2024-01-01' THEN t.sale_price ELSE 0 END) AS revenue_2023,
       SUM(CASE WHEN t.transaction_date >= '2024-01-01' AND t.transaction_date < '2025-01-01' THEN t.sale_price ELSE 0 END) AS revenue_2024,
       SUM(t.sale_price) AS total
FROM transactions t
JOIN properties p ON p.property_id = t.property_id
JOIN districts d  ON d.district_id = p.district_id
WHERE t.status = 'Completed'
GROUP BY d.district_id, d.district_name
ORDER BY total DESC;

-- =====================================================================
-- F. ADVANCED ANALYTICS (subqueries, CTEs and window functions)
-- =====================================================================

-- F1. Correlated subquery: properties priced above the average of their own type
SELECT p.property_id, pt.type_name, p.street_address, p.asking_price,
       (SELECT ROUND(AVG(p2.asking_price), 0) FROM properties p2 WHERE p2.type_id = p.type_id) AS type_average
FROM properties p
JOIN property_types pt ON pt.type_id = p.type_id
WHERE p.asking_price > (SELECT AVG(p2.asking_price) FROM properties p2 WHERE p2.type_id = p.type_id)
ORDER BY pt.type_name, p.asking_price DESC;

-- F2. Subquery in HAVING: districts whose average asking price is above the Berlin-wide average
SELECT d.district_name, COUNT(*) AS properties, ROUND(AVG(p.asking_price), 0) AS avg_asking_price
FROM properties p
JOIN districts d ON d.district_id = p.district_id
GROUP BY d.district_id, d.district_name
HAVING AVG(p.asking_price) > (SELECT AVG(asking_price) FROM properties)
ORDER BY avg_asking_price DESC;

-- F3. Days on market: latest completed sale of each sold property against its latest listing date
WITH latest_sale AS (
    SELECT t.property_id, t.transaction_date, t.sale_price,
           ROW_NUMBER() OVER (PARTITION BY t.property_id ORDER BY t.transaction_date DESC) AS rn
    FROM transactions t
    WHERE t.status = 'Completed'
)
SELECT pt.type_name,
       COUNT(*)                                                   AS sold_properties,
       ROUND(AVG(DATEDIFF(ls.transaction_date, p.listing_date)), 0) AS avg_days_on_market,
       ROUND(AVG(100 * ls.sale_price / p.asking_price), 1)        AS avg_sale_as_pct_of_asking
FROM latest_sale ls
JOIN properties p      ON p.property_id = ls.property_id
JOIN property_types pt ON pt.type_id = p.type_id
WHERE ls.rn = 1
GROUP BY pt.type_id, pt.type_name
ORDER BY avg_days_on_market;

-- F4. Repeat interest: available properties with 2+ viewings and an average interest level of at least 3
SELECT p.property_id, pt.type_name, p.street_address, p.asking_price,
       COUNT(pv.viewing_id)             AS viewings,
       ROUND(AVG(pv.interest_level), 1) AS avg_interest
FROM properties p
JOIN property_types pt ON pt.type_id = p.type_id
JOIN property_viewings pv ON pv.property_id = p.property_id
WHERE p.status = 'Available'
GROUP BY p.property_id, pt.type_name, p.street_address, p.asking_price
HAVING COUNT(pv.viewing_id) >= 2 AND AVG(pv.interest_level) >= 3
ORDER BY avg_interest DESC, viewings DESC;

-- F5. Biggest buyer in each district (ROW_NUMBER)
WITH buyer_spend AS (
    SELECT d.district_name,
           CONCAT(c.first_name, ' ', c.last_name) AS buyer,
           SUM(t.sale_price) AS spent,
           ROW_NUMBER() OVER (PARTITION BY d.district_id ORDER BY SUM(t.sale_price) DESC) AS rn
    FROM transactions t
    JOIN properties p ON p.property_id = t.property_id
    JOIN districts d  ON d.district_id = p.district_id
    JOIN clients c    ON c.client_id = t.buyer_id
    WHERE t.status = 'Completed'
    GROUP BY d.district_id, d.district_name, c.client_id, c.first_name, c.last_name
)
SELECT district_name, buyer, spent
FROM buyer_spend
WHERE rn = 1
ORDER BY spent DESC;

-- F6. Cumulative revenue over time (running total by completed sale)
SELECT transaction_date, property_id, sale_price,
       SUM(sale_price) OVER (ORDER BY transaction_date, transaction_id) AS cumulative_revenue
FROM transactions
WHERE status = 'Completed'
ORDER BY transaction_date, transaction_id;

-- F7. Call the stored report procedure
CALL sp_agent_report(2024);