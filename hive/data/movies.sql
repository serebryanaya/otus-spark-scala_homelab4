CREATE DATABASE IF NOT EXISTS movie_db;
USE movie_db;

CREATE TABLE IF NOT EXISTS movie_db.data_films (
    title STRING,
    kinopoisk_id STRING,
    imdb_id STRING,
    year INT,
    rating_kinopoisk float,
    rating_imdb float,
    age_limit STRING,
    genres ARRAY<STRING>,
    countries ARRAY<STRING>,
    director STRING,
    budget_usd DOUBLE,
    fees_usd DOUBLE,
    description_kinopoisk STRING,
    description_imdb STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '|'
COLLECTION ITEMS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

LOAD DATA local INPATH '/data/data_films_converted.csv' OVERWRITE INTO TABLE movie_db.data_films;

CREATE TABLE IF NOT EXISTS movie_db.imdb_films (
    title STRING,
    year INT,
    rating float,
    age_limit STRING,
    genres ARRAY<STRING>,
    country ARRAY<STRING>,
    director STRING,
    budget BIGINT,
    fees BIGINT,
    description STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '|'
COLLECTION ITEMS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ("skip.header.line.count"="1");

LOAD DATA local INPATH '/data/imdb_films_converted.csv' OVERWRITE INTO TABLE movie_db.imdb_films;

CREATE TABLE IF NOT EXISTS movie_db.rating_comparison_joined AS
SELECT 
    df.title as title_kp,
    df.year as year_kp,
    df.rating_kinopoisk,
    df.rating_imdb as rating_imdb_from_kp,
    ABS(df.rating_kinopoisk - df.rating_imdb) as rating_difference,
    df.age_limit as age_limit_kp,
    df.director as director_kp,
    CASE 
        WHEN df.rating_kinopoisk > df.rating_imdb THEN 'Kinopoisk Higher'
        WHEN df.rating_kinopoisk < df.rating_imdb THEN 'IMDB Higher'
        ELSE 'Equal'
    END as rating_comparison
FROM movie_db.data_films df
INNER JOIN movie_db.imdb_films imdb ON df.title = imdb.title
WHERE df.rating_kinopoisk IS NOT NULL 
  AND imdb.rating IS NOT NULL
  AND df.year > 2000;

ALTER TABLE movie_db.rating_comparison_joined SET TBLPROPERTIES ('description' = 'Витрина демонстрирует различия в оценках фильмов в Kinopoisk и IMDB');



CREATE TABLE IF NOT EXISTS movie_db.top_rated_movies AS
SELECT 
    title,
    year,
    rating,
    budget,
    fees,
    (fees - budget) as profit
FROM imdb_films
WHERE budget > 0 AND fees > 0
ORDER BY rating DESC
LIMIT 50;

ALTER TABLE movie_db.top_rated_movies SET TBLPROPERTIES ('description' = 'Витрина демонстрирует топ-50 самых высокооцененных фильмов по рейтингу IMDB с анализом их финансовой эффективности');

CREATE TABLE IF NOT EXISTS movie_db.year_age_analysis AS
SELECT 
    year,
    age_limit,
    COUNT(*) as movie_count,
    ROUND(AVG(rating), 2) as avg_rating,
    ROUND(AVG(budget), 2) as avg_budget,
    ROUND(AVG(fees), 2) as avg_fees,
    SUM(budget) as total_budget_year,
    SUM(fees) as total_fees_year,
    ROUND(AVG(fees - budget), 2) as avg_profit
FROM imdb_films
WHERE year BETWEEN 2000 AND 2025
GROUP BY year, age_limit
HAVING COUNT(*) >= 1
ORDER BY year DESC, movie_count DESC;

ALTER TABLE movie_db.year_age_analysis SET TBLPROPERTIES ('description' = 'Витрина демонстрирует тенденции в киноиндустрии по годам (с 2000 года) и возрастным категориям');

CREATE TABLE IF NOT EXISTS movie_db.movie_rankings_after_2000 AS
SELECT 
    title,
    year,
    rating,
    RANK() OVER (PARTITION BY year ORDER BY rating DESC) as year_rank,
    COUNT(*) OVER (PARTITION BY year) as count_movies_in_year
FROM imdb_films
WHERE rating > 0 AND year > 2000;

ALTER TABLE movie_db.movie_rankings_after_2000 SET TBLPROPERTIES ('description' = 'Витрина демонстрирует рейтинг среди фильмов того же года выпуска (данные после 2000 года)');


CREATE TABLE IF NOT EXISTS movie_db.year_trends_comparison AS
WITH yearly_data AS (

    SELECT 
        year,
        COUNT(*) as films_count,
        ROUND(AVG(rating_kinopoisk), 2) as avg_rating_kp,
        ROUND(AVG(rating_imdb), 2) as avg_rating_imdb,
        ROUND(AVG(budget_usd), 2) as avg_budget,
        ROUND(AVG(fees_usd), 2) as avg_fees,
        'data_films' as source
    FROM movie_db.data_films
    WHERE year IS NOT null and year > 2000
    GROUP BY year
    
    UNION ALL
    
    SELECT 
        year,
        COUNT(*) as films_count,
        NULL as avg_rating_kp,
        ROUND(AVG(rating), 2) as avg_rating_imdb,
        ROUND(AVG(budget), 2) as avg_budget,
        ROUND(AVG(fees), 2) as avg_fees,
        'imdb_films' as source
    FROM movie_db.imdb_films
    WHERE year IS NOT null and year > 2000
    GROUP BY year
),
yearly_joined AS (
    SELECT 
        yd.year,
        yd.source,
        yd.films_count,
        yd.avg_rating_kp,
        yd.avg_rating_imdb,
        yd.avg_budget,
        yd.avg_fees,
        ROUND(yd.avg_fees - yd.avg_budget, 2) as avg_profit,
        LAG(yd.films_count) OVER (PARTITION BY yd.source ORDER BY yd.year) as prev_year_count
    FROM yearly_data yd
)
SELECT 
    yj.*,
    CASE 
        WHEN yj.prev_year_count IS NOT NULL AND yj.prev_year_count > 0 
        THEN ROUND((yj.films_count - yj.prev_year_count) * 100.0 / yj.prev_year_count, 2)
        ELSE NULL 
    END as growth_percentage
FROM yearly_joined yj
ORDER BY yj.source, yj.year DESC;

ALTER TABLE movie_db.year_trends_comparison SET TBLPROPERTIES ('description' = 'Витрина демонстрирует тенденции в кинематографе по годам начиная с 2001 года. Сравнивает показатели из двух источников данных (data_films и imdb_films), включая количество фильмов, средние рейтинги, бюджеты');


