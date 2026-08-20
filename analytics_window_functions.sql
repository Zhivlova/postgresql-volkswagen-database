-- ============================================================
-- Volkswagen Database
-- Window Functions / Analytics
-- PostgreSQL 18
-- ============================================================
-- ============================================================
-- 1. Детальная аналитика цен автомобилей по моделям
-- ============================================================
WITH car_prices AS (
    SELECT
        c.id AS car_id,
        c.vin,
        p.model,
        p.date_of_production,
        p.price
    FROM cars AS c
    INNER JOIN profiles AS p
        ON p.car_id = c.id
    WHERE p.price IS NOT NULL
      AND p.model IS NOT NULL
),
analytics AS (
    SELECT
        *,

        AVG(price) OVER (
            PARTITION BY model
        AS model_avg_price,

        LAG(price) OVER (
            PARTITION BY model
            ORDER BY price, car_id
        ) AS previous_price,

        AVG(price) OVER (
            PARTITION BY model
            ORDER BY price, car_id
        ) AS running_avg_price,

        ROW_NUMBER() OVER (
            PARTITION BY model
            ORDER BY price DESC, car_id
        ) AS price_row_number,

        PERCENT_RANK() OVER (
            PARTITION BY model
            ORDER BY price
        ) AS price_percentile

FROM car_prices
)
SELECT
    car_id,
    vin,
    model,
    date_of_production,
    price,

    ROUND(model_avg_price, 2) AS model_avg_price

    ROUND(
        price - model_avg_price,
        2
    ) AS price_deviation,

    previous_price,
    price - previous_price AS price_diff,
    ROUND(running_avg_price, 2) AS running_avg_price,
    price_row_number,
    ROUND(price_percentile::numeric, 4) AS price_percentile

FROM analytics
ORDER BY
    model,
    price DESC,
    car_id;

-- ============================================================
-- 2. Автомобили с ценой выше средней по модели и входящие в топ-10% по цене
-- ============================================================
WITH ranked_cars AS (
    SELECT
        c.id AS car_id,
        c.vin,
        p.model,
        p.price,

        AVG(p.price) OVER (
            PARTITION BY p.model
        ) AS model_avg_price,

        PERCENT_RANK() OVER (
            PARTITION BY p.model
            ORDER BY p.price
        ) AS price_percentile

    FROM cars AS c
    INNER JOIN profiles AS p
        ON p.car_id = c.id
    WHERE p.price IS NOT NULL
      AND p.model IS NOT NULL
)
SELECT
    car_id,
    vin,
    model,
    price,

    ROUND(model_avg_price, 2) AS model_avg_price,
    ROUND(price_percentile::numeric, 4) AS price_percentile,

    ROUND(
        (
            price / NULLIF(model_avg_price, 0) - 1
        ) * 100,
        2
    ) AS above_average_percent

FROM ranked_cars
WHERE price > model_avg_price
  AND price_percentile >= 0.90

ORDER BY
    model,
    price DESC,
    car_id;

