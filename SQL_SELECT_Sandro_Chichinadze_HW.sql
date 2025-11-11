
/* =====================================================================
FILE: SQL_SELECT_Sandro_Chichinadze_HW.sql
AUTHOR: Sandro Chichinadze
PURPOSE: Solutions for SELECT tasks (CTE, Subquery, JOIN per task), revised per mentor feedback.
NOTES:
- Schema-qualified with "public."
- No hardcoded IDs (use names via UPPER() comparisons).
- No window functions.
- Explicit JOIN types.
- No ordinal positions in GROUP BY/ORDER BY.
- Each query is preceded by Task Conditions and Business Logic Interpretation.
- "Approach Recommendation" is added to each task.
- Date filtering since April 2017 uses EXTRACT(YEAR/MONTH).
- Part 2 Task 1 CTE optimized to avoid timeouts (no correlated subqueries).
===================================================================== */


/* =====================================================================
PART 1 — Task 1 (Animation movies 2017–2019, rental_rate > 1)
TASK CONDITIONS:
List Animation movies released between 2017 and 2019 (inclusive),
with rate more than 1; sort alphabetically.

BUSINESS LOGIC INTERPRETATION:
- Genre identified by public.category.name = 'Animation' (case-insensitive via UPPER()).
- Release period inclusive between 2017 and 2019.
- “rate more than 1” refers to public.film.rental_rate > 1.

APPROACH RECOMMENDATION:
- JOIN is typically the simplest and fastest here; CTE improves readability; Subquery is compact.
===================================================================== */

-- CTE
WITH animation_category AS (
    SELECT c.category_id
    FROM public.category AS c
    WHERE UPPER(c.name) = 'ANIMATION'
),
animation_films AS (
    SELECT fc.film_id
    FROM public.film_category AS fc
    INNER JOIN animation_category AS ac
        ON ac.category_id = fc.category_id
)
SELECT f.film_id, f.title, f.release_year, f.rental_rate
FROM public.film AS f
INNER JOIN animation_films AS af
    ON af.film_id = f.film_id
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;


/* Subquery */
SELECT f.film_id, f.title, f.release_year, f.rental_rate
FROM public.film AS f
WHERE f.film_id IN (
    SELECT fc.film_id
    FROM public.film_category AS fc
    INNER JOIN public.category AS c
        ON c.category_id = fc.category_id
    WHERE UPPER(c.name) = 'ANIMATION'
)
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;


/* JOIN (Recommended) */
SELECT DISTINCT f.film_id, f.title, f.release_year, f.rental_rate
FROM public.film AS f
INNER JOIN public.film_category AS fc
    ON fc.film_id = f.film_id
INNER JOIN public.category AS c
    ON c.category_id = fc.category_id
WHERE UPPER(c.name) = 'ANIMATION'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;


/* =====================================================================
PART 1 — Task 2 (Revenue per store since April 2017; address+address2)
TASK CONDITIONS:
Calculate each rental store's revenue after March 2017 (since April).
Include: one address column (address + address2), and revenue.

BUSINESS LOGIC INTERPRETATION:
- Revenue = SUM(public.payment.amount).
- Attribution path: payment -> rental -> inventory -> store.
- Filter: since 2017-04 (inclusive) using EXTRACT(YEAR/MONTH).
- Full address via CONCAT_WS(', ', address, address2) to handle NULLs.

APPROACH RECOMMENDATION:
- JOIN is most efficient for a single-pass aggregation; CTE is fine for clarity; Subquery is readable but can be slower.
===================================================================== */

-- CTE
WITH filtered_payments AS (
    SELECT p.payment_id, p.amount, p.payment_date, p.rental_id
    FROM public.payment AS p
    WHERE (EXTRACT(YEAR  FROM p.payment_date) > 2017)
       OR (EXTRACT(YEAR  FROM p.payment_date) = 2017 AND EXTRACT(MONTH FROM p.payment_date) >= 4)
),
store_revenue AS (
    SELECT i.store_id, SUM(fp.amount) AS revenue
    FROM filtered_payments AS fp
    INNER JOIN public.rental AS r
        ON r.rental_id = fp.rental_id
    INNER JOIN public.inventory AS i
        ON i.inventory_id = r.inventory_id
    GROUP BY i.store_id
)
SELECT s.store_id,
       CONCAT_WS(', ', a.address, a.address2) AS full_address,
       sr.revenue
FROM store_revenue AS sr
INNER JOIN public.store AS s
    ON s.store_id = sr.store_id
INNER JOIN public.address AS a
    ON a.address_id = s.address_id
ORDER BY full_address ASC;


/* Subquery */
SELECT s.store_id,
       CONCAT_WS(', ', a.address, a.address2) AS full_address,
       (
           SELECT SUM(p.amount)
           FROM public.payment AS p
           INNER JOIN public.rental AS r
               ON r.rental_id = p.rental_id
           INNER JOIN public.inventory AS i2
               ON i2.inventory_id = r.inventory_id
           WHERE ((EXTRACT(YEAR  FROM p.payment_date) > 2017)
               OR (EXTRACT(YEAR  FROM p.payment_date) = 2017 AND EXTRACT(MONTH FROM p.payment_date) >= 4))
             AND i2.store_id = s.store_id
       ) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
    ON a.address_id = s.address_id
ORDER BY full_address ASC;


/* JOIN (Recommended) */
SELECT s.store_id,
       CONCAT_WS(', ', a.address, a.address2) AS full_address,
       SUM(p.amount) AS revenue
FROM public.payment AS p
INNER JOIN public.rental AS r
    ON r.rental_id = p.rental_id
INNER JOIN public.inventory AS i
    ON i.inventory_id = r.inventory_id
INNER JOIN public.store AS s
    ON s.store_id = i.store_id
INNER JOIN public.address AS a
    ON a.address_id = s.address_id
WHERE (EXTRACT(YEAR  FROM p.payment_date) > 2017)
   OR (EXTRACT(YEAR  FROM p.payment_date) = 2017 AND EXTRACT(MONTH FROM p.payment_date) >= 4)
GROUP BY s.store_id, a.address, a.address2
ORDER BY full_address ASC;


/* =====================================================================
PART 1 — Task 3 (Top-5 actors by #movies since >2015)
TASK CONDITIONS:
Top-5 actors by number of movies (released after 2015) they took part in.
Columns: first_name, last_name, number_of_movies; sort by number_of_movies DESC.

BUSINESS LOGIC INTERPRETATION:
- Only films with film.release_year > 2015.
- Count DISTINCT films per actor (avoid duplicates).

APPROACH RECOMMENDATION:
- JOIN solution is shortest and performant; CTE adds clarity for filters; Subquery is tidy.
===================================================================== */

-- CTE
WITH films_since_2016 AS (
    SELECT f.film_id
    FROM public.film AS f
    WHERE f.release_year > 2015
),
actor_counts AS (
    SELECT fa.actor_id, COUNT(DISTINCT fa.film_id) AS number_of_movies
    FROM public.film_actor AS fa
    INNER JOIN films_since_2016 AS fs
        ON fs.film_id = fa.film_id
    GROUP BY fa.actor_id
)
SELECT a.first_name, a.last_name, ac.number_of_movies
FROM actor_counts AS ac
INNER JOIN public.actor AS a
    ON a.actor_id = ac.actor_id
ORDER BY ac.number_of_movies DESC, a.last_name ASC, a.first_name ASC
LIMIT 5;


/* Subquery */
SELECT a.first_name, a.last_name, t.number_of_movies
FROM public.actor AS a
INNER JOIN (
    SELECT fa.actor_id, COUNT(DISTINCT fa.film_id) AS number_of_movies
    FROM public.film_actor AS fa
    INNER JOIN public.film AS f
        ON f.film_id = fa.film_id
    WHERE f.release_year > 2015
    GROUP BY fa.actor_id
) AS t
    ON t.actor_id = a.actor_id
ORDER BY t.number_of_movies DESC, a.last_name ASC, a.first_name ASC
LIMIT 5;


/* JOIN (Recommended) */
SELECT a.first_name, a.last_name,
       COUNT(DISTINCT f.film_id) AS number_of_movies
FROM public.actor AS a
INNER JOIN public.film_actor AS fa
    ON fa.actor_id = a.actor_id
INNER JOIN public.film AS f
    ON f.film_id = fa.film_id
WHERE f.release_year > 2015
GROUP BY a.first_name, a.last_name
ORDER BY number_of_movies DESC, a.last_name ASC, a.first_name ASC
LIMIT 5;


/* =====================================================================
PART 1 — Task 4 (Counts per year for Drama/Travel/Documentary; NULL->0)
TASK CONDITIONS:
Show per release_year the counts of Drama, Travel, Documentary films.
Columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies.
Sort by release_year DESC; handle NULLs as 0.

BUSINESS LOGIC INTERPRETATION:
- Identify genres via public.category.name IN (...) with UPPER().
- Films can be multi-genre; each genre counted independently.
- Pivot via conditional sums with COALESCE.

APPROACH RECOMMENDATION:
- JOIN solution is minimal and performs well; CTE helps readability; Subquery is fine too.
===================================================================== */

-- CTE
WITH targeted AS (
    SELECT f.release_year, c.name AS category_name
    FROM public.film AS f
    INNER JOIN public.film_category AS fc
        ON fc.film_id = f.film_id
    INNER JOIN public.category AS c
        ON c.category_id = fc.category_id
    WHERE UPPER(c.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY')
)
SELECT t.release_year,
       COALESCE(SUM(CASE WHEN UPPER(t.category_name) = 'DRAMA'       THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
       COALESCE(SUM(CASE WHEN UPPER(t.category_name) = 'TRAVEL'      THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
       COALESCE(SUM(CASE WHEN UPPER(t.category_name) = 'DOCUMENTARY' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM targeted AS t
GROUP BY t.release_year
ORDER BY t.release_year DESC;


/* Subquery */
SELECT yr.release_year,
       COALESCE(SUM(CASE WHEN UPPER(yr.category_name) = 'DRAMA'       THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
       COALESCE(SUM(CASE WHEN UPPER(yr.category_name) = 'TRAVEL'      THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
       COALESCE(SUM(CASE WHEN UPPER(yr.category_name) = 'DOCUMENTARY' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM (
    SELECT f.release_year, c.name AS category_name
    FROM public.film AS f
    INNER JOIN public.film_category AS fc
        ON fc.film_id = f.film_id
    INNER JOIN public.category AS c
        ON c.category_id = fc.category_id
    WHERE UPPER(c.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY')
) AS yr
GROUP BY yr.release_year
ORDER BY yr.release_year DESC;


/* JOIN (Recommended) */
SELECT f.release_year,
       COALESCE(SUM(CASE WHEN UPPER(c.name) = 'DRAMA'       THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
       COALESCE(SUM(CASE WHEN UPPER(c.name) = 'TRAVEL'      THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
       COALESCE(SUM(CASE WHEN UPPER(c.name) = 'DOCUMENTARY' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM public.film AS f
INNER JOIN public.film_category AS fc
    ON fc.film_id = f.film_id
INNER JOIN public.category AS c
    ON c.category_id = fc.category_id
WHERE UPPER(c.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY')
GROUP BY f.release_year
ORDER BY f.release_year DESC;


/* =====================================================================
PART 2 — Task 1 (Top-3 employees by revenue in 2017 + last store in 2017)
TASK CONDITIONS:
Show which three employees generated the most revenue in 2017.
Assumptions:
- staff may work in several stores; show the store they worked in last (in 2017).
- if staff processed the payment then they work in that same store.
- consider only payment_date.

BUSINESS LOGIC INTERPRETATION:
- Revenue = SUM(payment.amount) in 2017 per staff.
- Last store in 2017 = store from the staff's latest 2017 payment.
- Optimized CTE: avoid correlated subqueries by pre-computing latest (date,id) and joining.

APPROACH RECOMMENDATION:
- Optimized CTE below preferred; Subquery is straightforward; JOIN is fine but still needs a "latest" pick.
===================================================================== */

-- Optimized CTE (Recommended) — no correlated subqueries, avoids timeouts
WITH payments_2017 AS (
  SELECT p.payment_id, p.amount, p.payment_date, p.rental_id, p.staff_id
  FROM public.payment AS p
  WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
),
staff_revenue AS (
  SELECT p2017.staff_id, SUM(p2017.amount) AS revenue_2017
  FROM payments_2017 AS p2017
  GROUP BY p2017.staff_id
),
last_date_per_staff AS (
  SELECT p.staff_id, MAX(p.payment_date) AS max_date_2017
  FROM payments_2017 AS p
  GROUP BY p.staff_id
),
last_payment_ids AS (
  SELECT p.staff_id, MAX(p.payment_id) AS last_payment_id
  FROM payments_2017 AS p
  INNER JOIN last_date_per_staff AS d
    ON d.staff_id = p.staff_id AND p.payment_date = d.max_date_2017
  GROUP BY p.staff_id
),
last_store_2017 AS (
  SELECT l.staff_id, i.store_id AS last_store_id
  FROM last_payment_ids AS l
  INNER JOIN public.payment AS p
    ON p.payment_id = l.last_payment_id
  INNER JOIN public.rental  AS r
    ON r.rental_id = p.rental_id
  INNER JOIN public.inventory AS i
    ON i.inventory_id = r.inventory_id
)
SELECT s.staff_id,
       s.first_name,
       s.last_name,
       sr.revenue_2017,
       ls.last_store_id,
       CONCAT_WS(', ', a.address, a.address2) AS last_store_address
FROM staff_revenue AS sr
INNER JOIN public.staff AS s
  ON s.staff_id = sr.staff_id
LEFT JOIN last_store_2017 AS ls
  ON ls.staff_id = s.staff_id
LEFT JOIN public.store AS st
  ON st.store_id = ls.last_store_id
LEFT JOIN public.address AS a
  ON a.address_id = st.address_id
ORDER BY sr.revenue_2017 DESC, s.last_name ASC, s.first_name ASC
LIMIT 3;


/* Subquery */
SELECT s.staff_id,
       s.first_name,
       s.last_name,
       (
         SELECT SUM(p.amount)
         FROM public.payment AS p
         WHERE p.staff_id = s.staff_id
           AND EXTRACT(YEAR FROM p.payment_date) = 2017
       ) AS revenue_2017,
       (
         SELECT i2.store_id
         FROM public.payment AS p2
         INNER JOIN public.rental AS r2
           ON r2.rental_id = p2.rental_id
         INNER JOIN public.inventory AS i2
           ON i2.inventory_id = r2.inventory_id
         WHERE p2.staff_id = s.staff_id
           AND EXTRACT(YEAR FROM p2.payment_date) = 2017
         ORDER BY p2.payment_date DESC, p2.payment_id DESC
         LIMIT 1
       ) AS last_store_id
FROM public.staff AS s
ORDER BY revenue_2017 DESC NULLS LAST, s.last_name ASC, s.first_name ASC
LIMIT 3;


/* JOIN */
WITH staff_revenue AS (
  SELECT p.staff_id, SUM(p.amount) AS revenue_2017
  FROM public.payment AS p
  WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
  GROUP BY p.staff_id
)
SELECT s.staff_id, s.first_name, s.last_name,
       sr.revenue_2017,
       (
         SELECT i2.store_id
         FROM public.payment AS p2
         INNER JOIN public.rental AS r2
           ON r2.rental_id = p2.rental_id
         INNER JOIN public.inventory AS i2
           ON i2.inventory_id = r2.inventory_id
         WHERE p2.staff_id = s.staff_id
           AND EXTRACT(YEAR FROM p2.payment_date) = 2017
         ORDER BY p2.payment_date DESC, p2.payment_id DESC
         LIMIT 1
       ) AS last_store_id
FROM staff_revenue AS sr
INNER JOIN public.staff AS s
  ON s.staff_id = sr.staff_id
ORDER BY sr.revenue_2017 DESC, s.last_name ASC, s.first_name ASC
LIMIT 3;


/* =====================================================================
PART 2 — Task 2 (Top-5 most rented movies + MPA audience descriptions)
TASK CONDITIONS:
Show 5 movies with the highest number of rentals and the expected audience description
based on Motion Picture Association rating (film.rating).

BUSINESS LOGIC INTERPRETATION:
- Popularity = COUNT(rental.rental_id) per film via inventory->rental.
- Map rating to description (per mentor):
  'G'      -> 'All Ages'
  'PG'     -> 'Parental Guidance Suggested'
  'PG-13'  -> 'Inappropriate for Children Under 13'
  'R'      -> 'Children Under 17 Require Accompanying Adult'
  'NC-17'  -> 'Inappropriate for Children Under 17'

APPROACH RECOMMENDATION:
- JOIN is concise; CTE separates counting from labeling; Subquery is fine.
===================================================================== */

-- CTE
WITH film_rentals AS (
  SELECT i.film_id, COUNT(r.rental_id) AS rentals_count
  FROM public.inventory AS i
  INNER JOIN public.rental AS r
    ON r.inventory_id = i.inventory_id
  GROUP BY i.film_id
)
SELECT f.title,
       fr.rentals_count,
       CASE f.rating
         WHEN 'G'      THEN 'All Ages'
         WHEN 'PG'     THEN 'Parental Guidance Suggested'
         WHEN 'PG-13'  THEN 'Inappropriate for Children Under 13'
         WHEN 'R'      THEN 'Children Under 17 Require Accompanying Adult'
         WHEN 'NC-17'  THEN 'Inappropriate for Children Under 17'
         ELSE NULL
       END AS expected_audience
FROM film_rentals AS fr
INNER JOIN public.film AS f
  ON f.film_id = fr.film_id
ORDER BY fr.rentals_count DESC, f.title ASC
LIMIT 5;


/* Subquery */
SELECT f.title,
       t.rentals_count,
       CASE f.rating
         WHEN 'G'      THEN 'All Ages'
         WHEN 'PG'     THEN 'Parental Guidance Suggested'
         WHEN 'PG-13'  THEN 'Inappropriate for Children Under 13'
         WHEN 'R'      THEN 'Children Under 17 Require Accompanying Adult'
         WHEN 'NC-17'  THEN 'Inappropriate for Children Under 17'
         ELSE NULL
       END AS expected_audience
FROM public.film AS f
INNER JOIN (
  SELECT i.film_id, COUNT(r.rental_id) AS rentals_count
  FROM public.inventory AS i
  INNER JOIN public.rental AS r
    ON r.inventory_id = i.inventory_id
  GROUP BY i.film_id
) AS t
  ON t.film_id = f.film_id
ORDER BY t.rentals_count DESC, f.title ASC
LIMIT 5;


/* JOIN (Recommended) */
SELECT f.title,
       COUNT(r.rental_id) AS rentals_count,
       CASE f.rating
         WHEN 'G'      THEN 'All Ages'
         WHEN 'PG'     THEN 'Parental Guidance Suggested'
         WHEN 'PG-13'  THEN 'Inappropriate for Children Under 13'
         WHEN 'R'      THEN 'Children Under 17 Require Accompanying Adult'
         WHEN 'NC-17'  THEN 'Inappropriate for Children Under 17'
         ELSE NULL
       END AS expected_audience
FROM public.film AS f
INNER JOIN public.inventory AS i
  ON i.film_id = f.film_id
INNER JOIN public.rental AS r
  ON r.inventory_id = i.inventory_id
GROUP BY f.title, f.rating
ORDER BY rentals_count DESC, f.title ASC
LIMIT 5;


/* =====================================================================
PART 3 — V1 (Gap: latest release_year -> current year)
TASK CONDITIONS:
For each actor, compute the gap (in years) between their latest film release_year
and the current year.

BUSINESS LOGIC INTERPRETATION:
- Latest release_year per actor via MAX over actor’s films.
- Current year via EXTRACT(YEAR FROM CURRENT_DATE).

APPROACH RECOMMENDATION:
- JOIN/CTE both clear and fast; Subquery is compact.
===================================================================== */

-- CTE
WITH actor_last_year AS (
  SELECT fa.actor_id, MAX(f.release_year) AS last_release_year
  FROM public.film_actor AS fa
  INNER JOIN public.film AS f
    ON f.film_id = fa.film_id
  GROUP BY fa.actor_id
)
SELECT a.first_name,
       a.last_name,
       (EXTRACT(YEAR FROM CURRENT_DATE)::INT - aly.last_release_year) AS inactivity_years
FROM actor_last_year AS aly
INNER JOIN public.actor AS a
  ON a.actor_id = aly.actor_id
ORDER BY inactivity_years DESC, a.last_name ASC, a.first_name ASC;


/* Subquery */
SELECT a.first_name,
       a.last_name,
       (EXTRACT(YEAR FROM CURRENT_DATE)::INT -
        (
          SELECT MAX(f.release_year)
          FROM public.film_actor AS fa2
          INNER JOIN public.film AS f
            ON f.film_id = fa2.film_id
          WHERE fa2.actor_id = a.actor_id
        )
       ) AS inactivity_years
FROM public.actor AS a
ORDER BY inactivity_years DESC NULLS LAST, a.last_name ASC, a.first_name ASC;


/* JOIN (Recommended) */
SELECT a.first_name,
       a.last_name,
       (EXTRACT(YEAR FROM CURRENT_DATE)::INT - t.last_release_year) AS inactivity_years
FROM public.actor AS a
INNER JOIN (
  SELECT fa.actor_id, MAX(f.release_year) AS last_release_year
  FROM public.film_actor AS fa
  INNER JOIN public.film AS f
    ON f.film_id = fa.film_id
  GROUP BY fa.actor_id
) AS t
  ON t.actor_id = a.actor_id
ORDER BY inactivity_years DESC, a.last_name ASC, a.first_name ASC;


/* =====================================================================
PART 3 — V2 (Max sequential gap between films per actor)
TASK CONDITIONS:
For each actor, compute the longest gap between consecutive film release_years.

BUSINESS LOGIC INTERPRETATION:
- Collect distinct (actor, release_year).
- For each (actor, year) find next higher year: MIN(year2) WHERE year2 > year.
- Gap = next_year - current_year; report MAX gap per actor.

APPROACH RECOMMENDATION:
- JOIN-based self-join with MIN is efficient; CTE is very readable; Subquery is compact but heavier.
===================================================================== */

-- CTE
WITH actor_years AS (
  SELECT DISTINCT fa.actor_id, f.release_year
  FROM public.film_actor AS fa
  INNER JOIN public.film AS f
    ON f.film_id = fa.film_id
),
next_year_per_row AS (
  SELECT ay.actor_id,
         ay.release_year AS current_year,
         MIN(ay2.release_year) AS next_year
  FROM actor_years AS ay
  LEFT JOIN actor_years AS ay2
    ON ay2.actor_id = ay.actor_id
   AND ay2.release_year > ay.release_year
  GROUP BY ay.actor_id, ay.release_year
),
gap_values AS (
  SELECT n.actor_id, (n.next_year - n.current_year) AS gap_years
  FROM next_year_per_row AS n
  WHERE n.next_year IS NOT NULL
),
max_gap_per_actor AS (
  SELECT gv.actor_id, MAX(gv.gap_years) AS max_sequential_gap_years
  FROM gap_values AS gv
  GROUP BY gv.actor_id
)
SELECT a.first_name, a.last_name, mg.max_sequential_gap_years
FROM max_gap_per_actor AS mg
INNER JOIN public.actor AS a
  ON a.actor_id = mg.actor_id
ORDER BY mg.max_sequential_gap_years DESC, a.last_name ASC, a.first_name ASC;


/* Subquery */
SELECT a.first_name,
       a.last_name,
       (
         SELECT MAX(next_year - current_year)
         FROM (
           SELECT ay.release_year AS current_year,
                  (
                    SELECT MIN(ay2.release_year)
                    FROM (
                      SELECT DISTINCT fa2.actor_id, f2.release_year
                      FROM public.film_actor AS fa2
                      INNER JOIN public.film AS f2
                        ON f2.film_id = fa2.film_id
                    ) AS ay2
                    WHERE ay2.actor_id = a.actor_id
                      AND ay2.release_year > ay.release_year
                  ) AS next_year
           FROM (
             SELECT DISTINCT fa.actor_id, f.release_year
             FROM public.film_actor AS fa
             INNER JOIN public.film AS f
               ON f.film_id = fa.film_id
             WHERE fa.actor_id = a.actor_id
           ) AS ay
         ) AS gaps_for_actor
         WHERE next_year IS NOT NULL
       ) AS max_sequential_gap_years
FROM public.actor AS a
ORDER BY max_sequential_gap_years DESC NULLS LAST, a.last_name ASC, a.first_name ASC;


/* JOIN (Recommended) */
WITH actor_years AS (
  SELECT DISTINCT fa.actor_id, f.release_year
  FROM public.film_actor AS fa
  INNER JOIN public.film AS f
    ON f.film_id = fa.film_id
),
next_year_per_row AS (
  SELECT ay.actor_id,
         ay.release_year AS current_year,
         MIN(ay2.release_year) AS next_year
  FROM actor_years AS ay
  LEFT JOIN actor_years AS ay2
    ON ay2.actor_id = ay.actor_id
   AND ay2.release_year > ay.release_year
  GROUP BY ay.actor_id, ay.release_year
),
gap_values AS (
  SELECT n.actor_id, (n.next_year - n.current_year) AS gap_years
  FROM next_year_per_row AS n
  WHERE n.next_year IS NOT NULL
),
max_gap_per_actor AS (
  SELECT gv.actor_id, MAX(gv.gap_years) AS max_sequential_gap_years
  FROM gap_values AS gv
  GROUP BY gv.actor_id
)
SELECT a.first_name, a.last_name, mg.max_sequential_gap_years
FROM max_gap_per_actor AS mg
INNER JOIN public.actor AS a
  ON a.actor_id = mg.actor_id
ORDER BY mg.max_sequential_gap_years DESC, a.last_name ASC, a.first_name ASC;


/* ============================== EOF ============================== */
