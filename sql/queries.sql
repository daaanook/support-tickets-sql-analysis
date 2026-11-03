-- Customer Support Tickets: SQL queries (SQLite)
-- Table: tickets (ticket_id, customer_age, customer_gender, product_purchased,
--   date_of_purchase, ticket_type, ticket_subject, ticket_description, ticket_status,
--   resolution, ticket_priority, ticket_channel, first_response_time,
--   time_to_resolution, csat, age_band)

-- Q1. Which columns are filled for each ticket status?
SELECT ticket_status,
       COUNT(*)                                   AS tickets,
       SUM(first_response_time IS NOT NULL)       AS with_first_response,
       SUM(time_to_resolution IS NOT NULL)        AS with_resolution,
       SUM(csat IS NOT NULL)                      AS with_csat
FROM tickets
GROUP BY ticket_status
ORDER BY tickets DESC;

-- Q2. Are the time columns consistent? (closed tickets)
SELECT COUNT(*)                                          AS closed_tickets,
       SUM(time_to_resolution < first_response_time)     AS resolved_before_first_response,
       ROUND(100.0 * SUM(time_to_resolution < first_response_time) / COUNT(*), 1) AS pct
FROM tickets
WHERE ticket_status = 'Closed';

-- Q3. Time span of the timestamps
SELECT MIN(first_response_time) AS earliest_response,
       MAX(first_response_time) AS latest_response,
       MIN(time_to_resolution)  AS earliest_resolution,
       MAX(time_to_resolution)  AS latest_resolution
FROM tickets;

-- Q4. Is the ticket text usable?
SELECT COUNT(*) AS tickets,
       SUM(ticket_description LIKE '%{product_purchased}%') AS description_with_unfilled_placeholder
FROM tickets;

-- Q5. Tickets by type with share of total (window function)
SELECT ticket_type,
       COUNT(*) AS tickets,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM tickets
GROUP BY ticket_type
ORDER BY tickets DESC;

-- Q6. Tickets by channel with share of total
SELECT ticket_channel,
       COUNT(*) AS tickets,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM tickets
GROUP BY ticket_channel
ORDER BY tickets DESC;

-- Q7. Most frequent product for each ticket type (CTE + RANK)
WITH counts AS (
    SELECT ticket_type, product_purchased, COUNT(*) AS tickets
    FROM tickets
    GROUP BY ticket_type, product_purchased
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY ticket_type ORDER BY tickets DESC) AS rnk
    FROM counts
)
SELECT ticket_type, product_purchased, tickets
FROM ranked
WHERE rnk = 1
ORDER BY ticket_type;

-- Q8. Ticket status
SELECT ticket_status,
       COUNT(*) AS tickets,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM tickets
GROUP BY ticket_status
ORDER BY tickets DESC;

-- Q9. Share of closed tickets by priority
SELECT ticket_priority,
       COUNT(*) AS tickets,
       SUM(ticket_status = 'Closed') AS closed,
       ROUND(100.0 * SUM(ticket_status = 'Closed') / COUNT(*), 1) AS closed_pct
FROM tickets
GROUP BY ticket_priority
ORDER BY CASE ticket_priority
             WHEN 'Critical' THEN 1 WHEN 'High' THEN 2
             WHEN 'Medium' THEN 3 ELSE 4 END;

-- Q10. Overall satisfaction
SELECT COUNT(csat)                                   AS rated_tickets,
       ROUND(AVG(csat), 2)                           AS avg_rating,
       ROUND(100.0 * SUM(csat >= 4) / COUNT(csat), 1) AS satisfied_pct,
       ROUND(100.0 * SUM(csat <= 2) / COUNT(csat), 1) AS dissatisfied_pct
FROM tickets
WHERE csat IS NOT NULL;

-- Q11. Rating distribution
SELECT CAST(csat AS INT) AS rating,
       COUNT(*) AS tickets,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM tickets
WHERE csat IS NOT NULL
GROUP BY rating
ORDER BY rating;

-- Q12. Satisfaction by channel
SELECT ticket_channel,
       COUNT(csat)                                    AS rated,
       ROUND(AVG(csat), 2)                            AS avg_rating,
       ROUND(100.0 * SUM(csat >= 4) / COUNT(csat), 1) AS satisfied_pct
FROM tickets
WHERE csat IS NOT NULL
GROUP BY ticket_channel
ORDER BY avg_rating DESC;

-- Q13. Satisfaction by ticket type
SELECT ticket_type,
       COUNT(csat)                                    AS rated,
       ROUND(AVG(csat), 2)                            AS avg_rating,
       ROUND(100.0 * SUM(csat >= 4) / COUNT(csat), 1) AS satisfied_pct
FROM tickets
WHERE csat IS NOT NULL
GROUP BY ticket_type
ORDER BY avg_rating DESC;

-- Q14. Satisfaction by priority
SELECT ticket_priority,
       COUNT(csat)         AS rated,
       ROUND(AVG(csat), 2) AS avg_rating
FROM tickets
WHERE csat IS NOT NULL
GROUP BY ticket_priority
ORDER BY avg_rating DESC;

-- Q15. Satisfaction by customer age band
SELECT age_band,
       COUNT(csat)         AS rated,
       ROUND(AVG(csat), 2) AS avg_rating
FROM tickets
WHERE csat IS NOT NULL
GROUP BY age_band
ORDER BY age_band;

-- Q16. Best and worst products by average rating (at least 40 rated tickets)
WITH product_scores AS (
    SELECT product_purchased,
           COUNT(csat)         AS rated,
           ROUND(AVG(csat), 2) AS avg_rating
    FROM tickets
    WHERE csat IS NOT NULL
    GROUP BY product_purchased
    HAVING COUNT(csat) >= 40
),
ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY avg_rating DESC) AS best_rank,
           RANK() OVER (ORDER BY avg_rating ASC)  AS worst_rank
    FROM product_scores
)
SELECT product_purchased, rated, avg_rating,
       CASE WHEN best_rank <= 3 THEN 'highest' ELSE 'lowest' END AS group_name
FROM ranked
WHERE best_rank <= 3 OR worst_rank <= 3
ORDER BY avg_rating DESC;

