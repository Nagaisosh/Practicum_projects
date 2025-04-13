/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Галкина М.М.
 * Дата: 18.10.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT count(id) AS total_players, -- общее количества игроков
sum(payer) AS total_payers, -- расчет платящих игроков
ROUND((sum(payer)::NUMERIC/count(id)),2) AS share_of_paying_players -- доля платящих игроков
FROM fantasy.users;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
SELECT r.race AS race, -- раса персонажа
SUM(u.payer) AS total_payers, -- расчет платящих игроков
COUNT(u.id) AS total_players, -- общее количества игроков
ROUND((sum(u.payer)::NUMERIC/count(u.id)::numeric),2) AS share_of_paying_players -- доля платящих игроков от общего количества игроков
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id=r.race_id -- присоединение таблицы race к users
GROUP BY race -- группировка по расе
ORDER BY total_payers DESC; -- сортировка по количеству платящих игроков в порядке убывания 

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT COUNT(amount) AS total_purchases, -- общее количество покупок
SUM(amount) AS sum_purchases, -- сумма всех покупок
MIN(amount) AS min_purchases, -- минимальная стоимость покупки
MAX(amount) AS max_purchases, -- максимальная стоимость покупки
ROUND(AVG(amount)::NUMERIC ,2) AS avg_purchases, -- среднее значение
PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median, -- медиана
ROUND(STDDEV(amount)::NUMERIC,2) AS stand_dev  --стандартное отклонение
FROM fantasy.events; 

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT (SELECT COUNT(amount) -- общее количество покупок
FROM fantasy.events
WHERE amount=0) AS free_purchases, -- фильтр, выбирающий только покупки с нулевой стоимостью
(SELECT COUNT(amount)
FROM fantasy.events
WHERE amount=0)::numeric /COUNT(amount)::numeric  AS share_of_purchases -- расчёт доли покупок с нулевой стоимостью от общего числа покупок 
FROM fantasy.events; 


-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь
SELECT
-- разделение игроков на 2 группы 
CASE 
	WHEN u.payer = 1
	THEN 'платящий'
	WHEN u.payer = 0 
	THEN 'неплатящий'
END AS payer_type,
COUNT(DISTINCT e.id) AS count_players, -- расчёт общего кол-ва игроков, совершающих покупки
ROUND(((COUNT(amount))::NUMERIC / COUNT(DISTINCT e.id)::NUMERIC),2) AS avg_purchases, -- среднее количество покупок
ROUND((SUM(amount)::numeric/COUNT(DISTINCT e.id)::numeric),2) AS avg_cost --средняя суммарная стоимость покупок на одного игрока 
FROM fantasy.events AS e 
FULL JOIN fantasy.users AS u ON e.id=u.id -- присоединение таблицы users к events
WHERE e.amount >0 -- фильтр для исключения покупок с нулевой стоимостью 
GROUP BY payer_type;


-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь
SELECT i.game_items AS item_type, -- название эпического предмета
COUNT(e.transaction_id) AS item_transactions, -- общее количество внутриигровых продаж в абсолютном значении
COUNT(e.transaction_id)::NUMERIC / (SELECT COUNT(e.transaction_id)
FROM fantasy.events AS e)::NUMERIC AS share_of_transactions, -- общее количество внутриигровых продаж в относительном значении
COUNT(DISTINCT e.id)::NUMERIC / (SELECT COUNT(DISTINCT e.id) FROM fantasy.events AS e)::NUMERIC AS share_of_players -- доля игроков, которые покупали предмет
FROM fantasy.items AS i
FULL JOIN fantasy.events AS e ON i.item_code = e.item_code 
WHERE e.amount>0 -- исключение покупок с нулевой стоимостью
GROUP BY i.game_items -- группировка по названию эпического предмета
ORDER BY item_transactions DESC; -- сортировка в порядке убывания популярности эпического предмета

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
-- расчёт общего количества и количества платящих игроков в разрезе по расе
WITH inf_1 AS (
SELECT r.race AS race,
COUNT(u.id) AS total_players -- общее кол-во зарегистрированных игроков
FROM fantasy.race AS r
LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id --присоединение таблицы users к race
GROUP BY race), -- группировка результатов по расе
-- расчёт информации о стоимости покупок и количестве платящих игроков в разрезе расы 
inf_2 AS (
SELECT r.race AS race,
COUNT(DISTINCT e.id) AS buyers, -- кол-во игроков, совершивших покупку
COUNT(e.amount) AS count_purchase, 
sum(e.amount) AS sum_purchase,
AVG(e.amount) AS avg_purchase_amount,
ROUND((COUNT(e.amount)::NUMERIC/COUNT(DISTINCT e.id)::NUMERIC),2) AS share_of_count_purchase, -- среднее количество покупок на одного игрока
ROUND((sum(e.amount)::NUMERIC/COUNT(DISTINCT e.id)::NUMERIC),2) AS share_of_sum_purchase --средняя стоимость одной покупки на одного игрока
FROM fantasy.race AS r
LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id --  присоединение таблицы users к race
LEFT JOIN fantasy.events AS e ON u.id=e.id --присоединение таблицы events к users+race
WHERE e.amount>0 -- фильтр, чтобы исключить нулевые транзакции 
GROUP BY race ), -- группировка результатов по расе
inf_3 AS (
SELECT r.race AS race,
count(DISTINCT e.id) AS total_payers -- общее кол-во платящих игроков
FROM fantasy.events AS e
LEFT JOIN fantasy.users AS u ON e.id=u.id
LEFT JOIN fantasy.race AS r ON u.race_id =r.race_id 
WHERE u.payer = 1 -- фильтр, чтобы выделить только платящих игроков
GROUP BY r.race) -- группировка результатов по расе
SELECT inf_1.race,
inf_1.total_players,
inf_2.buyers,
ROUND((inf_2.buyers::NUMERIC/inf_1.total_players::NUMERIC),2) AS  share_of_players, -- доля игроков, совершивших покупку от общего количества
inf_3.total_payers,
ROUND((inf_3.total_payers::NUMERIC/inf_2.buyers::NUMERIC),2) AS share_of_payers, --доля платящих игроков от количества игроков, которые совершили покупки
inf_2.share_of_count_purchase,
ROUND((inf_2.avg_purchase_amount::NUMERIC),2) AS avg_purchase_amount, --средняя суммарная стоимость всех покупок на одного игрока
inf_2.share_of_sum_purchase
FROM inf_1
LEFT JOIN inf_2 ON inf_1.race=inf_2.race
LEFT JOIN inf_3 ON inf_2.race=inf_3.race
LEFT JOIN fantasy.race AS r ON inf_1.race=r.race;

-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь
	WITH inf_1 AS (
SELECT id AS player_id,
amount,
LAG(date) OVER (PARTITION BY id ORDER BY date) AS previous_purchase_date, -- дата предыдущей транзакции
EXTRACT(DAY FROM (date::timestamp - LAG(date) OVER (PARTITION BY id ORDER BY date)::timestamp)) AS between_days --кол-во дней между транзакциями
FROM fantasy.events ),
	inf_2 AS (
SELECT player_id, 
amount,
COUNT(amount) AS count_purchase, -- общее кол-во покупок
ROUND(AVG(between_days),0) AS avg_days -- среднее кол-во дней между покупками
FROM inf_1
-- убираем покупки с нулевой стоимостью и пустые значения 
WHERE amount >0 
AND between_days IS NOT NULL 
GROUP BY player_id, amount),
	inf_3 AS (
SELECT e.id AS player_id,
count(DISTINCT e.id) AS payers -- расчет кол-ва платящих игроков
FROM fantasy.events AS e
LEFT JOIN fantasy.users AS u ON e.id=u.id
WHERE u.payer = 1 -- фильтр, чтобы выделить только платящих игроков
GROUP BY e.id),
	inf_4 AS ( 
SELECT NTILE(3) OVER(ORDER BY inf_2.avg_days) AS rang_of_buyers, -- ранжируем игроков на 3 примерно одинаковые группы по среднему кол-ву дней между покупками
inf_2.avg_days,
inf_2.amount,
inf_2.count_purchase,
inf_2.player_id,
inf_3.payers
FROM inf_2
LEFT JOIN inf_3 ON inf_2.player_id=inf_3.player_id
)
-- разделяем игроков по частоте покупок:
	SELECT CASE 
        WHEN rang_of_buyers = 1 THEN 'высокая частота'
        WHEN rang_of_buyers = 2 THEN 'умеренная частота'
        ELSE 'низкая частота'
    END AS type_of_buyers,
    COUNT (player_id) AS total_players, -- общее кол-во игроков, совершающих покупки
    COUNT (payers) AS total_payers, -- общее кол-во платящих игроков
    ROUND(( count (payers) ::NUMERIC / COUNT (player_id)::NUMERIC),2) AS share_of_payers, -- расчет доли платящих игроков от общего кол-ва
    ROUND ((avg(count_purchase)::NUMERIC),2) AS avg_purchase, -- расчет среднего кол-ва покупок на одного игрока
    ROUND((avg(avg_days)::NUMERIC),0) AS avg_days_of_purchase -- расчет среднего кол-ва дней между покупками на одного игрока
FROM inf_4
WHERE count_purchase >=25 -- фильтр, чтобы оставить только активных игроков
GROUP BY type_of_buyers;