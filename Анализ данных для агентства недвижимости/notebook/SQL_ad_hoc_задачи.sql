--Проект: Анализ данных для агентства недвижимости
--Дашборд: https://datalens.yandex/61cffb5o07owq

--AD-hoc задачи

-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--Добавлим столбец "регион" в зависимости от расположния города и определим периоды действия объявлений 
    region_and_period AS (
SELECT f.id, c.city, 
       CASE 
          WHEN c.city='Санкт-Петербург' THEN 'Санкт-Петербург'
          WHEN t."type"='город' THEN 'ЛенОбл'
       ELSE 'non category' END AS region,
       CASE 
          WHEN a.days_exposition<=30 THEN '1-30 days'
          WHEN a.days_exposition<=90 THEN '31-90 days'
          WHEN a.days_exposition<=180 THEN '91-180 days'
          WHEN a.days_exposition>=181 THEN '181+ days'
       ELSE 'non category' END AS period_exposition
FROM real_estate.flats f 
LEFT JOIN real_estate.city c ON f.city_id = c.city_id 
LEFT JOIN real_estate."type" t ON f.type_id = t.type_id
LEFT JOIN real_estate.advertisement a ON f.id =a.id
WHERE t."type"='город'),
--Добавим нумерацию полей для "периода действия объявления" для корректного вывода таблицы
row_num AS (
SELECT period_exposition,
       CASE 
          WHEN period_exposition='1-30 days' THEN 1
          WHEN period_exposition='31-90 days' THEN 2
          WHEN period_exposition='91-180 days' THEN 3
          WHEN period_exposition='181+ days' THEN 4
       ELSE '5' END AS ROW
FROM region_and_period
GROUP BY period_exposition)
--Итоговый запрос
SELECT rap.region,
       rap.period_exposition,
       COUNT (a.id) AS count,
       ROUND (COUNT (a.id)::numeric/SUM (COUNT (a.id)) OVER (PARTITION BY rap.region)*100,2) AS percent_period,
       ROUND (AVG (a.last_price::numeric/f.total_area::numeric),2) AS avg_price_sqm,
       ROUND (AVG (f.total_area::NUMERIC),2) AS avg_total_area,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) AS mediana_rooms,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) AS mediana_balcony,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floors_total) AS mediana_floors_total,
       ROUND(COUNT (a.id) FILTER (WHERE f.open_plan = 1)/COUNT (a.id)::NUMERIC*100,2) AS percent_open_plan
FROM real_estate.flats AS f
LEFT JOIN real_estate.advertisement a ON f.id=a.id
LEFT JOIN real_estate.city c ON f.city_id=c.city_id
LEFT JOIN real_estate."type" t ON f.type_id=t.type_id 
LEFT JOIN region_and_period AS rap ON f.id=rap.id
LEFT JOIN row_num AS rn ON rap.period_exposition=rn.period_exposition
WHERE f.id IN (SELECT * FROM filtered_id)
      AND a.first_day_exposition BETWEEN '01.01.2015' AND '31.12.2018'
      AND t."type" = 'город'
GROUP BY rap.region, rap.period_exposition, rn.row
ORDER BY rap.region DESC, rn.ROW;
-- Таблица:
-- region           | period_exposition   | count   | percent_period  | avg_price_sqm | avg_total_area | mediana_rooms | mediana_balcony | mediana_floors_total | percent_open_plan
-- -----------------|---------------------|---------|-----------------|---------------|----------------|---------------|-----------------|----------------------|------------------
-- Санкт-Петербург  | 1-30 days           | 1794    | 15.99           | 108919.78     | 54.66          | 2             | 1               | 10                   | 0.28
-- Санкт-Петербург  | 31-90 days          | 3020    | 26.92           | 110874.32     | 56.58          | 2             | 1               | 12                   | 0.60
----- 
-- ЛенОбл           | 1-30 days           | 340     | 12.02           | 71907.63      | 48.75          | 2             | 1               | 5                    | 0.59
-- ЛенОбл           | 31-90 days          | 864     | 30.55           | 67423.80      | 50.85          | 2             | 1               | 5                    | 0.23
----- 

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
set lc_time = 'ru_RU';
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--Определим месяц подачи объявления и месяц снятия (продажи) и отфильтруем выбросы
exposition AS (
SELECT a.id,
       EXTRACT ('MONTH' FROM a.first_day_exposition) AS begin_exposition_month, 
       EXTRACT ('MONTH'FROM (a.first_day_exposition::date+(a.days_exposition)*INTERVAL'1 day')) AS end_exposition_month 
FROM real_estate.advertisement a
LEFT JOIN real_estate.flats f ON f.id=a.id
LEFT JOIN real_estate."type" t ON f.type_id=t.type_id 
WHERE f.id IN (SELECT * FROM filtered_id)
      AND a.first_day_exposition BETWEEN '01.01.2015' AND '31.12.2018'
      AND t."type" = 'город'),
--Расчет статистики для "подачи объявления"
begin_exposition_month AS (
SELECT e.begin_exposition_month,
       COUNT (e.id) AS count,
       ROUND (AVG (a.last_price::numeric/f.total_area::numeric),2) AS avg_price_sqm,
       ROUND (AVG (f.total_area::NUMERIC),2) AS avg_total_area
FROM exposition AS e
LEFT JOIN real_estate.flats f ON f.id=e.id
LEFT JOIN real_estate.advertisement a ON f.id=a.id
GROUP BY e.begin_exposition_month),
--Расчет статистики для "снятия объявления"
end_exposition_month AS (
SELECT e.end_exposition_month,
       COUNT (e.id) AS count,
       ROUND (AVG (a.last_price::numeric/f.total_area::numeric),2) AS avg_price_sqm,
       ROUND (AVG (f.total_area::NUMERIC),2) AS avg_total_area
FROM exposition AS e
LEFT JOIN real_estate.flats f ON f.id=e.id
LEFT JOIN real_estate.advertisement a ON f.id=a.id
GROUP BY e.end_exposition_month)
--Итоговый запрос
SELECT TO_CHAR(TO_DATE(begin_exposition_month::VARCHAR, 'MM'), 'TMMon') AS begin_expos_month,
       RANK () OVER (ORDER BY bem.count DESC),
       bem.count,
       ROUND(bem.count/SUM (bem.count) OVER ()*100,2) AS percent_count,
       bem.avg_price_sqm,
       ROUND(bem.avg_price_sqm/AVG (bem.avg_price_sqm) OVER ()*100-100,2) AS dev_avg_price,
       bem.avg_total_area,
       ROUND(bem.avg_total_area/AVG (bem.avg_total_area) OVER ()*100-100,2) AS dev_total_area,
       TO_CHAR(TO_DATE(end_exposition_month::VARCHAR, 'MM'), 'TMMon') AS end_expos_month,
       RANK () OVER (ORDER BY eem.count DESC),
       eem.count,
       ROUND(eem.count/SUM (eem.count) OVER ()*100,2) AS percent_count,
       eem.avg_price_sqm,
       ROUND(eem.avg_price_sqm/AVG (eem.avg_price_sqm) OVER ()*100-100,2) AS dev_avg_price,
       eem.avg_total_area,
       ROUND(eem.avg_total_area/AVG (eem.avg_total_area) OVER ()*100-100,2) AS dev_total_area
FROM begin_exposition_month AS bem
LEFT JOIN end_exposition_month AS eem ON bem.begin_exposition_month=eem.end_exposition_month
ORDER BY bem.begin_exposition_month
-- Таблица:
-- begin_expos_month| rank   | count   | percent_period  | ----
-- -----------------|--------|---------|-----------------|-----
-- Jan              | 12     | 735     | 5.23            | ----
-- Feb              | 3      | 1369    | 9.75            | ----
-- Mar              | 8      | 1119    | 7.97            | ----
-- Apr              | 10     | 1021    | 7.27            | ----
----

--Общие выводы и рекомендации:
--Влияние факторов средней стоимости квадратного метра и общей площади помещения не выявляет какой-то закономерности в целом по анализируемому периоду данных.
--Большее количество реализованных квартир приходится на осень и начало зимы (сентябрь-ноябрь), что говорит о повышении спроса со стороны покупателей именно 
--в этот период - благоприятный период для выхода на рынок.
--Также можно рекомендовать заказчику для рассмотрения выхода на рынок направление: город Санкт-Петербург. Это обусловлено гораздо большим объемом рынка
--недвижимости и более высокой средней стоимостью квадратного метра, что поможет снизить возможные риски.