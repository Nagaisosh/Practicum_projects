/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Галкина М.М.
 * Дата: 06.11.2024
*/

-- Пример фильтрации данных от аномальных значений
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
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Напишите ваш запрос здесь
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
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    ),
-- Выведем объявления без выбросов:
	grouping AS (
SELECT *,
a.last_price/f.total_area AS price_of_metr, -- стоимость 1 м2
-- разделение на категории по местоположению
CASE
	WHEN c.city = 'Санкт-Петербург'
	THEN 'Санкт-Петербург'
	ELSE 'ЛенОбл'
END category,
-- разделение на категории по дням активности
CASE 
	WHEN a.days_exposition>0 AND a.days_exposition <31
	THEN 'До 1 месяца'
	WHEN a.days_exposition BETWEEN 31 AND 90
	THEN 'До 3 месяцев'
	WHEN a.days_exposition  BETWEEN 91 AND 180
	THEN 'До 6 месяцев'
	WHEN a.days_exposition >=181 
	THEN 'От 6 месяцев'
	ELSE 'Действующие'
END activity
FROM real_estate.flats f
LEFT JOIN real_estate.city c ON f.city_id=c.city_id
LEFT JOIN real_estate.advertisement a ON f.id=a.id
LEFT JOIN real_estate.type t ON f.type_id=t.type_id
WHERE f.id IN (SELECT * FROM filtered_id) -- объявления без выбросов
AND t.TYPE='город'  -- оставляем объявления в городах 
AND f.total_area > 0 -- исключаем данные, где площадь равна 0
AND a.last_price IS NOT NULL) -- исключаем данные, где стоимость квартир неизвестна 
-- Выведем результирующую таблицу
	SELECT category, 
activity, 
ROUND((AVG(price_of_metr)::NUMERIC),0) AS avg_price_of_metr, -- средняя стоимость 1м2
ROUND((AVG(total_area)::NUMERIC),0) AS avg_area, -- средняя площадь квартир
PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY rooms) AS rooms, -- медиана кол-во комнат
PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY balcony) AS balcony, -- медиана кол-ва балконов
PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY floors_total) AS floors_total -- медиана кол-ва этажей
FROM grouping 
WHERE activity <> 'Действующие' -- убираем объявления, которые еще не закрыты
GROUP BY category, activity -- делаем группировку по типу области и активности объявлений
ORDER BY category DESC, activity; -- сортируем сначала по области, а затем по активности объявлений

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Напишите ваш запрос здесь
WITH limits AS (
SELECT  
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM real_estate.flats ),
-- Найдем id объявлений, которые не содержат выбросы:
	filtered_id AS(
SELECT id
FROM real_estate.flats  
WHERE total_area < (SELECT total_area_limit FROM limits) 
AND rooms < (SELECT rooms_limit FROM limits) 
AND balcony < (SELECT balcony_limit FROM limits) 
AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)),
-- Выведем объявления без выбросов:
	filtred_date AS (
SELECT f.id,
f.total_area,
a.last_price/f.total_area AS price_of_metr, -- стоимость 1 м2
a.first_day_exposition,
a.days_exposition,
(a.first_day_exposition + INTERVAL '1 day' * a.days_exposition)::date AS last_day_exposition -- вычисляем день снятия объявления
FROM real_estate.flats f
JOIN real_estate.advertisement a ON f.id=a.id
WHERE f.id IN (SELECT * FROM filtered_id) -- объявления без выбросов
AND a.days_exposition IS NOT NULL -- оставляем только закрытые объявления
AND f.total_area > 0 -- исключаем данные, где площадь равна 0
AND a.last_price IS NOT NULL),   -- исключаем данные, где стоимость квартир неизвестна
-- Готовим данные для дальнейших исследований:
	result_date AS (
SELECT id,
total_area,
price_of_metr,
EXTRACT (MONTH FROM first_day_exposition) AS open_exposition, -- месяц открытия объявления
EXTRACT (MONTH FROM last_day_exposition) AS close_exposition -- месяц закрытия объявления
FROM filtred_date ),
-- Находим информацию в разрезе месяцев открытия объявлений:
	monthly_activity AS (
SELECT open_exposition AS month, 
COUNT(*) AS total_publications, -- общее кол-во открытых объявлений
AVG(total_area) AS avg_total_area, -- средняя площадь квартир
AVG(price_of_metr) AS avg_price_of_metr -- средняя стоимость 1 м2
FROM result_date
GROUP BY open_exposition),
-- Находим информацию в разрезе месяцев закрытия объявлений:
	monthly_closed AS (
SELECT close_exposition AS month,
COUNT(*) AS total_closed, -- общее кол-во закрытых объявлений 
AVG(total_area) AS avg_total_area, -- средняя площадь квартир
AVG(price_of_metr) AS avg_price_of_metr -- средняя стоимость 1 м2
FROM result_date
GROUP BY close_exposition)
-- Выводим результирующую информацию:
	SELECT CASE   
		WHEN m.MONTH = 1
		THEN 'Январь'
		WHEN m.MONTH = 2
		THEN 'Февраль'
		WHEN m.MONTH = 3
		THEN 'Март'
		WHEN m.MONTH = 4
		THEN 'Апрель'
		WHEN m.MONTH = 5
		THEN 'Май'
		WHEN m.MONTH = 6
		THEN 'Июнь'
		WHEN m.MONTH = 7
		THEN 'Июль'
		WHEN m.MONTH = 8
		THEN 'Август'
		WHEN m.MONTH = 9
		THEN 'Сентябрь' 
		WHEN m.MONTH = 10
		THEN 'Октябрь'
		WHEN m.MONTH = 11
		THEN 'Ноябрь'
		ELSE 'Декабрь'
	END AS month_name,
m.total_publications,
ROUND(m.avg_total_area::NUMERIC,0) AS avg_total_area,
ROUND(m.avg_price_of_metr::NUMERIC,0) AS avg_price_of_metr,
c.total_closed,
ROUND(c.avg_total_area::NUMERIC,0) AS avg_total_area,
ROUND(c.avg_price_of_metr::NUMERIC,0) AS avg_price_of_metr
FROM monthly_activity AS m
LEFT JOIN monthly_closed AS c ON m.month = c.MONTH
ORDER BY m.total_publications DESC;

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

-- Напишите ваш запрос здесь
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT f.id
    FROM real_estate.flats  f
    JOIN real_estate.city c ON f.city_id=c.city_id 
    WHERE 
        f.total_area < (SELECT total_area_limit FROM limits) 
        AND f.rooms < (SELECT rooms_limit FROM limits) 
        AND f.balcony < (SELECT balcony_limit FROM limits) 
        AND f.ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND f.ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
        AND c.city <> 'Санкт-Петербург' -- фильтр, чтобы оставить только населенный пункты Лен.области
    ),
-- Выведем объявления без выбросов, также объявения снятые с продажи:
	close_expositions AS (
SELECT *,
a.last_price/f.total_area AS price_of_metr, -- стоимость 1 м2 
a.days_exposition AS de,
c.city AS type_city,
a.id AS close_id
FROM real_estate.flats f
JOIN real_estate.advertisement a ON f.id=a.id
JOIN real_estate.city c ON f.city_id=c.city_id
WHERE f.id IN (SELECT * FROM filtered_id) -- объявления без выбросов
AND a.days_exposition IS NOT NULL  -- оставляем только закрытые объявления
AND f.total_area > 0 -- исключаем данные, где площадь равна 0
AND a.last_price IS NOT NULL),   -- исключаем данные, где стоимость квартир неизвестна
-- Считаем количество всех объявлений в Лен.области:
	total_expositions AS (
SELECT count(a.id) AS total_count, -- общее кол-во объявлений с учетом действующих
c.city AS type_city
FROM real_estate.flats f 
JOIN real_estate.advertisement a ON f.id=a.id
JOIN real_estate.city c ON f.city_id=c.city_id 
WHERE f.id IN (SELECT * FROM filtered_id) -- исключаем объяления, содержащие выбросы
GROUP BY c.city), -- группировка по населенному пункту
-- Считаем необходимую информацию для заказчика в разрезе населенных пунктов:
	result_inf AS (
SELECT 
ce.type_city,
ROUND((AVG(ce.de)::NUMERIC),0) AS avg_days_exposition, -- среднее значение дней активности объявления
count(ce.close_id) AS count_close_id, -- кол-во объявлений снятых с продажи
ROUND((count(ce.close_id)::NUMERIC/te.total_count::NUMERIC),2) AS share_of_expositions, -- доля объявлений, которые сняты с продажи
ROUND((AVG(ce.price_of_metr)::NUMERIC),0) AS avg_price_of_metr, -- средняя стоимость 1м2
ROUND((AVG(ce.total_area)::NUMERIC),0) AS avg_area, -- средняя площадь квартир
PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY ce.rooms) AS rooms, -- медиана кол-во комнат
PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY ce.balcony) AS balcony, -- медиана кол-ва балконов
PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY ce.floors_total) AS floors_total -- медиана кол-ва этажей
FROM close_expositions AS ce
FULL JOIN total_expositions AS te ON ce.type_city=te.type_city
GROUP BY ce.type_city, te.total_count)
-- Делим объявления на 4 категории по среднему значению дней активности объявления и формируем итоговую таблицу
	SELECT *,
NTILE (4) OVER (ORDER BY avg_days_exposition) AS group_number 
	FROM result_inf
WHERE count_close_id >20 -- фильтруем населенны пункты по кол-ву объявлений 
-- группируем по среднему значению дней активности объявления и количеству объявлений снятых с продажи:
ORDER BY avg_days_exposition, count_close_id DESC 
LIMIT 15; -- выводим только 15 значений