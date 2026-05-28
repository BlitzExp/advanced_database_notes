-- ============================================================
-- SQL Challenge 06 — Oracle Indexes: Solution
-- Run setup.sql before this file.
-- ============================================================

-- Optional SQL*Plus / SQLcl formatting
SET LINESIZE 180
SET PAGESIZE 100

-- Helper pattern used throughout:
-- 1. EXPLAIN PLAN FOR <query>;
-- 2. SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- ============================================================
-- Exercise 1 — Find the slow query
-- ============================================================

EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE site_id = 3;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Answers:
-- a) Usually TABLE ACCESS FULL.
-- b) site_id is low cardinality because it only has values 1–5.
-- c) A normal B-tree index on site_id usually would not help much because
--    each value can match around 20% of the table and SELECT * still needs
--    many table row lookups.

-- Optional test only. The optimizer may still prefer a full table scan.
CREATE INDEX idx_pv_site_id ON patient_visits(site_id);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;
/

EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE site_id = 3;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

DROP INDEX idx_pv_site_id;

-- ============================================================
-- Exercise 2 — Create an index on visit_date
-- ============================================================

CREATE INDEX idx_pv_visit_date
ON patient_visits(visit_date);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;
/

-- Last 30 days
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 30 AND SYSDATE;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Last 7 days
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 7 AND SYSDATE;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Last 700 days
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 700 AND SYSDATE;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Answers:
-- a) For 30 days, Oracle may use INDEX RANGE SCAN if the range is selective enough.
-- b) For 7 days, index use is more likely because fewer rows match.
-- c) For 700 days, Oracle will usually prefer TABLE ACCESS FULL because most rows match.
-- d) Range size affects selectivity. When the query returns a large part of the table,
--    scanning the table is often cheaper than using the index and then visiting many rows.

-- ============================================================
-- Exercise 3 — Composite index
-- ============================================================

CREATE INDEX idx_pv_patient_date
ON patient_visits(patient_id, visit_date);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;
/

-- Query using both columns in the composite index
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE patient_id = 1234
  AND visit_date > SYSDATE - 90;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Query using only the leading column
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE patient_id = 1234;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Query using only the trailing column
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE visit_date > SYSDATE - 90;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Answers:
-- a) Yes, the composite index should be useful for patient_id + visit_date.
-- b) Querying only visit_date usually does not use this composite index efficiently
--    because visit_date is not the leading column.
-- c) Composite indexes follow the leftmost-prefix rule. An index on
--    (patient_id, visit_date) can efficiently support patient_id alone or
--    patient_id + visit_date, but not visit_date alone.

-- ============================================================
-- Exercise 4 — Function that breaks an index
-- ============================================================

-- Normal numeric comparison; can use idx_pv_patient_date because patient_id
-- is the leading column.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE patient_id = 5432;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Function wrapped around the indexed column; normal index cannot be used directly.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE TO_CHAR(patient_id) = '5432';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Correct rewrite:
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE patient_id = 5432;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- If the function is unavoidable, create a function-based index:
CREATE INDEX idx_pv_patient_id_char
ON patient_visits(TO_CHAR(patient_id));

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;
/

EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE TO_CHAR(patient_id) = '5432';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

DROP INDEX idx_pv_patient_id_char;

-- Answers:
-- a) Without the function-based index, the second query usually uses TABLE ACCESS FULL.
-- b) The function changes the indexed expression. The normal numeric index stores
--    patient_id values, not TO_CHAR(patient_id) values.
-- c) Rewrite it as patient_id = 5432, or create a function-based index if needed.

-- ============================================================
-- Exercise 5 — Real-world scenarios
-- ============================================================

-- Scenario A answer:
-- Yes, add an index on the date column because analysts query by date range
-- on a large reporting table. Consider date partitioning too.
-- Concern: nightly ETL writes may be slower because indexes must be maintained.

-- Scenario B answer:
-- Add an index on customer_id because it is likely selective and useful for support lookups.
-- Do not add a simple B-tree index only on order_status unless a specific status is very selective.
-- If support often queries recent orders by status, consider a composite index such as
-- (order_status, created_at), but test it because the table has very heavy inserts.
-- Avoid bitmap indexes in this high-write OLTP scenario.

-- Scenario C answer:
-- Use a UNIQUE B-tree index on email because the column is unique and queried by equality.
-- If email search must be case-insensitive, use a unique function-based index on LOWER(email).

-- ============================================================
-- Cleanup
-- ============================================================

DROP INDEX idx_pv_patient_date;
DROP INDEX idx_pv_visit_date;