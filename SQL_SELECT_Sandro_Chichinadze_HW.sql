/* ==========================================================
TASK CONDITIONS:
List Animation movies released between 2017 and 2019 (inclusive),
with rate more than 1; sort alphabetically.

BUSINESS LOGIC INTERPRETATION:
- "Animation" identified by public.category.name = 'Animation' (no hardcoded IDs).
- Use film.release_year BETWEEN 2017 AND 2019 inclusive.
- "rate more than 1" = film.rental_rate > 1 (rating is MPAA text, so we use rental_rate).
========================================================== */

-- CTE
WITH animation_category AS (
  SELECT c.category_id
  FROM public.category AS c
  WHERE c.name = 'Animation'
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
  WHERE c.name = 'Animation'
)
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;


/* JOIN */
SELECT DISTINCT f.film_id, f.title, f.release_year, f.rental_rate
FROM public.film AS f
INNER JOIN public.film_category AS fc
  ON fc.film_id = f.film_id
INNER JOIN public.category AS c
  ON c.category_id = fc.category_id
WHERE c.name = 'Animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title ASC;

/* ==========================================================
TASK CONDITIONS:
Calculate each rental store's revenue after March 2017 (i.e., from 2017-04-01).
Include: one address column (address + address2), and revenue.

BUSINESS LOGIC INTERPRETATION:
- Revenue = SUM(public.payment.amount).
- Attribution path: payment -> rental -> inventory -> store.
- Filter: payment.payment_date >= DATE '2017-04-01'.
- Full address via CONCAT_WS(', ', address, address2) (handles NULLs).
========================================================== */

-- CTE
WITH filtered_payments AS (
  SELECT p.payment_id, p.amount, p.payment_date, p.rental_id
  FROM public.payment AS p
  WHERE p.payment_date >= DATE '2017-04-01'
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
         WHERE p.payment_date >= DATE '2017-04-01'
           AND i2.store_id = s.store_id
       ) AS revenue
FROM public.store AS s
INNER JOIN public.address AS a
  ON a.address_id = s.address_id
ORDER BY full_address ASC;


/* JOIN */
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
WHERE p.payment_date >= DATE '2017-04-01'
GROUP BY s.store_id, a.address, a.address2
ORDER BY full_address ASC;

/* ==========================================================
TASK CONDITIONS:
Top-5 actors by number of movies (released after 2015) they took part in.
Columns: first_name, last_name, number_of_movies; sort by number_of_movies DESC.

BUSINESS LOGIC INTERPRETATION:
- Only films with film.release_year > 2015.
- Count DISTINCT films per actor (avoid duplicates).
========================================================== */

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

/* JOIN */
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


/* ==========================================================
TASK CONDITIONS:
Show per release_year the counts of Drama, Travel, Documentary films.
Columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies.
Sort by release_year DESC; handle NULLs as 0.

BUSINESS LOGIC INTERPRETATION:
- Identify genres via public.category.name IN (...).
- Films can be multi-genre; each genre counted independently.
- Pivot via conditional sums with COALESCE.
========================================================== */

-- CTE
WITH targeted AS (
  SELECT f.release_year, c.name AS category_name
  FROM public.film AS f
  INNER JOIN public.film_category AS fc
    ON fc.film_id = f.film_id
  INNER JOIN public.category AS c
    ON c.category_id = fc.category_id
  WHERE c.name IN ('Drama', 'Travel', 'Documentary')
)
SELECT t.release_year,
       COALESCE(SUM(CASE WHEN t.category_name = 'Drama'       THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
       COALESCE(SUM(CASE WHEN t.category_name = 'Travel'      THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
       COALESCE(SUM(CASE WHEN t.category_name = 'Documentary' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM targeted AS t
GROUP BY t.release_year
ORDER BY t.release_year DESC;

/* Subquery */
SELECT yr.release_year,
       COALESCE(SUM(CASE WHEN yr.category_name = 'Drama'       THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
       COALESCE(SUM(CASE WHEN yr.category_name = 'Travel'      THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
       COALESCE(SUM(CASE WHEN yr.category_name = 'Documentary' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM (
  SELECT f.release_year, c.name AS category_name
  FROM public.film AS f
  INNER JOIN public.film_category AS fc
    ON fc.film_id = f.film_id
  INNER JOIN public.category AS c
    ON c.category_id = fc.category_id
  WHERE c.name IN ('Drama', 'Travel', 'Documentary')
) AS yr
GROUP BY yr.release_year
ORDER BY yr.release_year DESC;


/* JOIN */
SELECT f.release_year,
       COALESCE(SUM(CASE WHEN c.name = 'Drama'       THEN 1 ELSE 0 END), 0) AS number_of_drama_movies,
       COALESCE(SUM(CASE WHEN c.name = 'Travel'      THEN 1 ELSE 0 END), 0) AS number_of_travel_movies,
       COALESCE(SUM(CASE WHEN c.name = 'Documentary' THEN 1 ELSE 0 END), 0) AS number_of_documentary_movies
FROM public.film AS f
INNER JOIN public.film_category AS fc
  ON fc.film_id = f.film_id
INNER JOIN public.category AS c
  ON c.category_id = fc.category_id
WHERE c.name IN ('Drama', 'Travel', 'Documentary')
GROUP BY f.release_year
ORDER BY f.release_year DESC;


/* ==========================================================
TASK CONDITIONS:
Show which three employees generated the most revenue in 2017.
Assumptions:
- staff can work in several stores in a year; show the store they worked in last (in 2017).
- if staff processed the payment then they work in that same store.
- use only payment_date to determine year and recency.

BUSINESS LOGIC INTERPRETATION:
- Revenue = SUM(payment.amount) in 2017 per staff.
- Determine "last store" as the store tied to the most recent payment the staff processed in 2017.
  Without window functions: pick store_id from the staff’s latest 2017 payment via a correlated subquery
  (ORDER BY p.payment_date DESC, p.payment_id DESC LIMIT 1), resolved through rental->inventory->store.
========================================================== */

-- CTE
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
last_store_2017 AS (
  SELECT DISTINCT p2017.staff_id,
         /* pick the store of the latest 2017 payment */
         (
           SELECT i2.store_id
           FROM public.payment AS p2
           INNER JOIN public.rental AS r2
             ON r2.rental_id = p2.rental_id
           INNER JOIN public.inventory AS i2
             ON i2.inventory_id = r2.inventory_id
           WHERE p2.staff_id = p2017.staff_id
             AND EXTRACT(YEAR FROM p2.payment_date) = 2017
           ORDER BY p2.payment_date DESC, p2.payment_id DESC
           LIMIT 1
         ) AS last_store_id
  FROM payments_2017 AS p2017
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
       /* revenue in 2017 */
       (
         SELECT SUM(p.amount)
         FROM public.payment AS p
         WHERE p.staff_id = s.staff_id
           AND EXTRACT(YEAR FROM p.payment_date) = 2017
       ) AS revenue_2017,
       /* last store in 2017, taken from latest processed payment */
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
       ) AS last_store_id,
       /* address for that store */
       (
         SELECT CONCAT_WS(', ', a.address, a.address2)
         FROM public.payment AS p3
         INNER JOIN public.rental AS r3
           ON r3.rental_id = p3.rental_id
         INNER JOIN public.inventory AS i3
           ON i3.inventory_id = r3.inventory_id
         INNER JOIN public.store AS st3
           ON st3.store_id = i3.store_id
         INNER JOIN public.address AS a
           ON a.address_id = st3.address_id
         WHERE p3.staff_id = s.staff_id
           AND EXTRACT(YEAR FROM p3.payment_date) = 2017
         ORDER BY p3.payment_date DESC, p3.payment_id DESC
         LIMIT 1
       ) AS last_store_address
FROM public.staff AS s
ORDER BY revenue_2017 DESC NULLS LAST, s.last_name ASC, s.first_name ASC
LIMIT 3;


/* JOIN (aggregate + correlated pick for last store) */
WITH staff_revenue AS (
  SELECT p.staff_id, SUM(p.amount) AS revenue_2017
  FROM public.payment AS p
  WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
  GROUP BY p.staff_id
)
SELECT s.staff_id, s.first_name, s.last_name,
       sr.revenue_2017,
       /* choose last store via correlated subquery */
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


/* ==========================================================
TASK CONDITIONS:
Show 5 movies with the highest number of rentals and the expected audience age
based on Motion Picture Association rating (film.rating).

BUSINESS LOGIC INTERPRETATION:
- Popularity = COUNT(rental.rental_id) per film via inventory->rental.
- Map rating to age with CASE:
  G->0+, PG->10+, PG-13->13+, R->17+, NC-17->18+, else NULL.
- No window functions; use ORDER BY + LIMIT 5.
========================================================== */

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
         WHEN 'G'      THEN 0
         WHEN 'PG'     THEN 10
         WHEN 'PG-13'  THEN 13
         WHEN 'R'      THEN 17
         WHEN 'NC-17'  THEN 18
         ELSE NULL
       END AS expected_min_age
FROM film_rentals AS fr
INNER JOIN public.film AS f
  ON f.film_id = fr.film_id
ORDER BY fr.rentals_count DESC, f.title ASC
LIMIT 5;


/* Subquery */
SELECT f.title,
       t.rentals_count,
       CASE f.rating
         WHEN 'G'      THEN 0
         WHEN 'PG'     THEN 10
         WHEN 'PG-13'  THEN 13
         WHEN 'R'      THEN 17
         WHEN 'NC-17'  THEN 18
         ELSE NULL
       END AS expected_min_age
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


/* JOIN */
SELECT f.title,
       COUNT(r.rental_id) AS rentals_count,
       CASE f.rating
         WHEN 'G'      THEN 0
         WHEN 'PG'     THEN 10
         WHEN 'PG-13'  THEN 13
         WHEN 'R'      THEN 17
         WHEN 'NC-17'  THEN 18
         ELSE NULL
       END AS expected_min_age
FROM public.film AS f
INNER JOIN public.inventory AS i
  ON i.film_id = f.film_id
INNER JOIN public.rental AS r
  ON r.inventory_id = i.inventory_id
GROUP BY f.title, f.rating
ORDER BY rentals_count DESC, f.title ASC
LIMIT 5;


/* ==========================================================
TASK CONDITIONS:
For each actor, compute the gap (in years) between their latest film release_year
and the current year. Identify actors with longer inactivity.

BUSINESS LOGIC INTERPRETATION:
- Latest release_year per actor via MAX over actor’s films.
- Current year via EXTRACT(YEAR FROM CURRENT_DATE).
- Return actors and their gap; you can sort DESC to see longest inactivity first.
========================================================== */

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


/* JOIN */
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


/* ==========================================================
TASK CONDITIONS:
For each actor, compute the longest gap between consecutive film release_years.
Identify actors with the longest such gap (bigger = longer inactivity between roles).

BUSINESS LOGIC INTERPRETATION:
- For every (actor, film_year), find the next film_year of that actor:
    next_year = MIN(f2.release_year) WHERE f2.release_year > current_year.
- Gap = next_year - current_year. Take MAX gap per actor.
- No window functions: implement with correlated subqueries/self-joins.
========================================================== */

-- CTE
WITH actor_years AS (
  SELECT DISTINCT fa.actor_id, f.release_year
  FROM public.film_actor AS fa
  INNER JOIN public.film AS f
    ON f.film_id = fa.film_id
),
gaps AS (
  SELECT ay.actor_id,
         ay.release_year AS current_year,
         (
           SELECT MIN(ay2.release_year)
           FROM actor_years AS ay2
           WHERE ay2.actor_id = ay.actor_id
             AND ay2.release_year > ay.release_year
         ) AS next_year
  FROM actor_years AS ay
),
gap_values AS (
  SELECT g.actor_id,
         (g.next_year - g.current_year) AS gap_years
  FROM gaps AS g
  WHERE g.next_year IS NOT NULL
),
max_gap_per_actor AS (
  SELECT gv.actor_id, MAX(gv.gap_years) AS max_sequential_gap_years
  FROM gap_values AS gv
  GROUP BY gv.actor_id
)
SELECT a.first_name,
       a.last_name,
       mg.max_sequential_gap_years
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


/* JOIN (self-join on the “next” year via inequality + GROUP BY MIN) */
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


