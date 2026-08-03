-- Анализ данных с помощью SQL и создание дашборда в DataLens. Вычисление ключевых метрик продукта

-- дашборд: https://datalens.yandex/7rscqbapc30oq
--1. Получение общих данных
SELECT DISTINCT currency_code,
       SUM (revenue) AS total_revenue,
       COUNT (order_id) AS total_orders,
       AVG (revenue) AS avg_revenue_per_order,
       COUNT (DISTINCT user_id) AS total_users
FROM afisha.purchases
GROUP BY 1
ORDER BY  2 DESC
-- Таблица:
-- currency_code  | total_revenue       | total_orders        | avg_revenue_per_order    | total_users
-- ---------------|---------------------|---------------------|--------------------------|------------
-- rub            | 157130432           | 286961              | 547.570922412914         | 21422
-- kzt            | 25340978            | 5073                | 4995.309819793927        | 1362

--2. Распределение выручки в разрезе устройств
SELECT device_type_canonical,
       SUM (revenue) AS total_revenue,
       COUNT (order_id) AS total_orders,
       AVG (revenue) AS avg_revenue_per_order,
       ROUND(SUM (revenue::numeric)/(SUM (SUM (revenue::numeric)) OVER ()), 3) AS revenue_share
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY 1
ORDER BY 5 DESC
-- Таблица:
-- device_type_canonical  | total_revenue       | total_orders        | avg_revenue_per_order    | revenue_share
-- -----------------------|---------------------|---------------------|--------------------------|--------------
-- mobile                 | 124633528           | 229021              | 544.1976894989267        | 0.793
-- desktop                | 31851612            | 56759               | 561.1687862756498        | 0.203
-- tablet                 | 640988.7            | 1176                | 545.0581287524733        | 0.004
-- other                  | 5133.7603           | 2                   | 2566.8800659179688       | 0
-- tv                     | 1299.16             | 3                   | 433.0533447265625        | 0

--3. Распределение выручки в разрезе типа мероприятий
SELECT event_type_main,
       SUM (revenue) AS total_revenue,
       COUNT (order_id) AS total_orders,
       AVG (revenue) AS avg_revenue_per_order,
       COUNT (DISTINCT event_name_code) AS total_event_name,
       AVG (tickets_count) AS avg_tickets,
       SUM (revenue) / SUM (tickets_count) AS avg_ticket_revenue,
       ROUND(SUM (revenue::numeric)/(SUM (SUM (revenue::numeric)) OVER ()), 3) AS revenue_share
FROM afisha.purchases AS p
LEFT JOIN afisha.events AS e USING (event_id)
WHERE currency_code = 'rub'
GROUP BY 1
ORDER BY 3 DESC
-- Таблица:
-- event_type_main  | total_revenue   | total_orders    | avg_revenue_per_order    | total_event_name | avg_tickets        | avg_ticket_revenue | revenue_share
-- -----------------|-----------------|-----------------|--------------------------|------------------|--------------------|--------------------|--------------
-- концерты         | 88705368        | 112418          | 789.0850212149544        | 6014             | 2.6570389083598712 | 296.97243044000817 | 0.565
-- театр            | 37141692        | 67733           | 548.3568227249012        | 4352             | 2.7600726381527468 | 198.67392002054046 | 0.236
-- другое           | 15579650        | 64572           | 241.28204110350754       | 3807             | 2.7648361518924611 | 87.26579697643547  | 0.099
-- спорт            | 3466726.8       | 21700           | 159.75414450427698       | 785              | 3.0534101382488479 | 52.32084320620595  | 0.022
----- 

--4. Динамика изменения значений
SELECT DATE_TRUNC('week', created_dt_msk)::date AS week,
       SUM (revenue) AS total_revenue,
       COUNT (order_id) AS total_orders,
       COUNT (DISTINCT user_id) AS total_users,
       SUM (revenue)/COUNT (order_id) AS revenue_per_order
FROM afisha.purchases p
WHERE currency_code = 'rub'
GROUP BY 1
ORDER BY 1
-- Таблица:
-- week         | total_revenue       | total_orders        | total_users    | revenue_per_order
-- -------------|---------------------|---------------------|----------------|------------------
-- 2024-05-27   | 911625.7            | 2024                | 805            | 450.4079483695652
-- 2024-06-03   | 3989499.0           | 7589                | 2238           | 525.6949532217684
-- 2024-06-10   | 4160552.8           | 7431                | 2153           | 559.8913672453236
---- 

--5. Выделение топ-сегментов
SELECT region_name,
       SUM (revenue) AS total_revenue,
       COUNT (order_id) AS total_orders,
       COUNT (DISTINCT user_id) AS total_users,
       SUM (tickets_count) AS total_tickets,
       SUM (revenue)/SUM (tickets_count) AS one_ticket_cost
FROM afisha.purchases p
LEFT JOIN afisha.events de USING (event_id)
LEFT JOIN afisha.city c USING (city_id)
LEFT JOIN afisha.regions r USING (region_id)
WHERE currency_code = 'rub'
GROUP BY 1
ORDER BY 2 desc
LIMIT 7
-- Таблица:
-- region_name         | total_revenue       | total_orders         | total_users    | total_tickets   | one_ticket_cost
-- --------------------|---------------------|----------------------|----------------|-----------------|------------------
-- Каменевский регион  | 61555204            | 91634                | 10646          | 253393          | 242.92385346082963
-- Североярская область| 25453390            | 44282                | 6735           | 125204          | 203.295342001853
-- Широковская область | 9793663.0           | 10502                | 2488           | 29621           | 330.6324229431822
---- 
