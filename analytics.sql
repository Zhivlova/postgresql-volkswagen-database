-- ============================================================
-- 01. Количество автомобилей по моделям
-- ============================================================

SELECT
    model,
    COUNT(*) AS cars_count
FROM car_profiles
GROUP BY model
ORDER BY cars_count DESC;


-- ============================================================
-- 02. Количество автомобилей по дилерам
-- ============================================================

SELECT
    d.dealer_id,
    d.dealer_name,
    COUNT(cd.car_id) AS cars_count
FROM dealers AS d
JOIN cars_dealers AS cd
    ON cd.dealer_id = d.dealer_id
GROUP BY d.dealer_id, d.dealer_name
ORDER BY cars_count DESC;


-- ============================================================
-- 03. Средняя цена в зависимости от типа кузова
-- ============================================================

SELECT
    bodywork,
    COUNT(*) AS cars_count,
    ROUND(AVG(price), 2) AS average_price
FROM car_profiles
GROUP BY bodywork
ORDER BY average_price DESC;


-- ============================================================
-- 04. Автомобили по цене выше средней
-- ============================================================

SELECT
    car_id,
    model,
    price
FROM (
    SELECT
        car_id,
        model,
        price,
        AVG(price) OVER () AS average_price
    FROM profiles
) AS p
WHERE price > average_price
ORDER BY price DESC;


-- ============================================================
-- 05. Самые популярные услуги
-- ============================================================

SELECT
    s.service_name,
    COUNT(cs.car_id) AS service_count
FROM services s
JOIN cars_services cs
    ON cs.service_id = s.id
GROUP BY s.id, s.service_name
ORDER BY service_count DESC;


-- ============================================================
-- 06. Статистика продаж по дилерам
-- ============================================================

SELECT
    d.dealer_id,
    d.dealer_name,
    COUNT(s.id) AS sold_cars,
    SUM(s.sale_price) AS total_revenue,
    ROUND(AVG(s.sale_price), 2) AS average_sale_price
FROM dealers AS d
JOIN sales AS s
    ON s.dealer_id = d.dealer_id
GROUP BY d.dealer_id, d.dealer_name
ORDER BY total_revenue DESC;


-- ============================================================
-- 07. Рейтинг дилеров по выручке
-- ============================================================
WITH dealer_sales AS (
    SELECT
        d.dealer_id,
        d.dealer_name,
        SUM(s.sale_price) AS total_revenue
    FROM dealers AS d
    JOIN sales AS s
        ON s.dealer_id = d.dealer_id
    GROUP BY d.dealer_id, d.dealer_name
)
SELECT
    dealer_id,
    dealer_name,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM dealer_sales
WHERE total_revenue > 0
ORDER BY revenue_rank;

--
---- ============================================================
---- 08. Cars more expensive than the average price
----     using CTE
---- ============================================================
--
--WITH average_price AS (
--    SELECT AVG(price) AS value
--    FROM car_profiles
--)
--SELECT
--    cp.model,
--    cp.price
--FROM car_profiles cp
--CROSS JOIN average_price ap
--WHERE cp.price > ap.value
--ORDER BY cp.price DESC;
--

-- ============================================================
-- 09. Наличие автомобилей у дилеров
-- ============================================================

SELECT
    d.dealer_id
    d.dealer_name,
    COUNT(p.car_id) AS cars_count,
    ROUND(AVG(p.price), 2) AS average_price,
    MIN(p.price) AS minimum_price,
    MAX(p.price) AS maximum_price
FROM dealers AS d
JOIN cars_dealers AS cd
    ON cd.dealer_id = d.dealer_id
JOIN profiles AS p
    ON p.car_id = cd.car_id
GROUP BY d.dealer_id, d.dealer_name
ORDER BY cars_count DESC;


-- ============================================================
-- 10. Продажи за месяц
-- ============================================================

SELECT
    DATE_TRUNC('month', sold_at) AS month,
    COUNT(*) AS sales_count,
    SUM(sale_price) AS revenue
FROM sales
GROUP BY DATE_TRUNC('month', sold_at)
ORDER BY month;