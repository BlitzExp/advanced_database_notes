-- ============================================================
-- EXERCISE 1 — Find the slow query
-- ============================================================
-- Original query:
-- SELECT * FROM patient_visits WHERE site_id = 3;
--
-- Questions:
-- a) What scan type do you see? Why?
-- b) site_id has values 1–5. Is this high or low cardinality?
-- c) Would adding an index on site_id help? Why or why not?
-- ============================================================

EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE site_id = 3;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

/*
Answers:

a) Expected scan type: TABLE ACCESS FULL.
   Oracle most likely does a full table scan because there is no index on site_id.
   Also, site_id is not selective because many rows have the same site_id value.

b) site_id is low cardinality.
   It only has 5 possible values: 1, 2, 3, 4, and 5.

c) A normal B-tree index on site_id would usually not help much.
   Since site_id has only 5 possible values, each value may return about 20% of the table.
   Because the query uses SELECT *, Oracle would still need to fetch many rows from the table.
   In that case, a full table scan is often cheaper than using an index.

Optional test index:
CREATE INDEX idx_pv_site_id ON patient_visits(site_id);
*/


-- ============================================================
-- EXERCISE 2 — Create an index and see if it helps
-- ============================================================
-- Create an index on visit_date.
-- Then run range queries and check the plan.
--
-- Questions:
-- a) Does Oracle use the index for the last 30 days?
-- b) Change the range to the last 7 days. Does the plan change?
-- c) Change to the last 700 days. What happens?
-- d) Why does the range size affect whether Oracle uses the index?
-- ============================================================

-- Step 1: Create the index.
CREATE INDEX idx_pv_visit_date
ON patient_visits(visit_date);

-- Step 2: Gather stats.
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'PATIENT_VISITS',
        cascade => TRUE
    );
END;
/

-- Step 3A: Last 30 days.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 30 AND SYSDATE;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Step 3B: Last 7 days.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 7 AND SYSDATE;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Step 3C: Last 700 days.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 700 AND SYSDATE;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

/*
Answers:

a) For the last 30 days, Oracle may use the index.
   Expected plan could include:
   - INDEX RANGE SCAN IDX_PV_VISIT_DATE
   - TABLE ACCESS BY INDEX ROWID
   This is because 30 days out of 730 days is relatively selective.

b) For the last 7 days, Oracle is even more likely to use the index.
   The range is smaller, so fewer rows are returned.
   Smaller result sets usually make indexes more useful.

c) For the last 700 days, Oracle will probably use TABLE ACCESS FULL.
   700 days out of 730 days is almost the whole table.
   Using the index would require visiting most rows anyway, so a full table scan is cheaper.

d) Range size affects index usage because of selectivity.
   Small range = fewer matching rows = index is useful.
   Large range = many matching rows = full table scan is usually cheaper.
*/


-- ============================================================
-- EXERCISE 3 — Composite index
-- ============================================================
-- You often query by both patient_id AND visit_date together:
-- WHERE patient_id = 1234 AND visit_date > SYSDATE - 90
--
-- Two options:
-- Option A: Two separate indexes, one per column.
-- Option B: One composite index, patient_id plus visit_date.
--
-- Questions:
-- a) Does the plan use the composite index?
-- b) Now try querying ONLY on visit_date, no patient_id.
--    Does the composite index get used? Why not?
-- c) What's the rule about column order in composite indexes?
-- ============================================================

CREATE INDEX idx_pv_patient_date
ON patient_visits(patient_id, visit_date);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => USER,
        tabname => 'PATIENT_VISITS',
        cascade => TRUE
    );
END;
/

-- Query using both columns.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE patient_id = 1234
  AND visit_date > SYSDATE - 90;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Query using only the leading column.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE patient_id = 1234;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Query using only the trailing column.
-- Important: If idx_pv_visit_date still exists, Oracle may use that single-column index.
-- To test only the composite index behavior, drop idx_pv_visit_date first.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE visit_date > SYSDATE - 90;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

/*
Answers:

a) Yes, the query using both patient_id and visit_date should use the composite index.
   Expected plan could include:
   - INDEX RANGE SCAN IDX_PV_PATIENT_DATE
   This works because the query filters by patient_id first, which is the leading column.

b) Querying only by visit_date usually does not use the composite index efficiently.
   The index is ordered as:
   (patient_id, visit_date)
   Oracle cannot efficiently jump to visit_date values without first using patient_id.
   If the single-column idx_pv_visit_date exists, Oracle may use that instead.

c) Rule: composite indexes are most effective from left to right.
   For an index on (patient_id, visit_date):
   - WHERE patient_id = 1234 can use it.
   - WHERE patient_id = 1234 AND visit_date > SYSDATE - 90 can use it.
   - WHERE visit_date > SYSDATE - 90 usually cannot use it efficiently because it skips patient_id.
*/


-- ============================================================
-- EXERCISE 4 — Function that breaks an index
-- ============================================================
-- There is an index on patient_id from Exercise 3 because patient_id is the
-- leading column of idx_pv_patient_date.
--
-- Questions:
-- a) What scan type did the second query use?
-- b) Why does wrapping a column in a function break index use?
-- c) How would you rewrite the second query to allow index use?
-- ============================================================

-- This query can use the index.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE patient_id = 5432;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- This query usually cannot use a normal index on patient_id.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE TO_CHAR(patient_id) = '5432';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Correct rewrite.
EXPLAIN PLAN FOR
SELECT *
FROM patient_visits
WHERE patient_id = TO_NUMBER('5432');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

/*
Answers:

a) The second query will usually use TABLE ACCESS FULL.
   This is because the indexed column is wrapped in TO_CHAR(patient_id).

b) Wrapping a column in a function changes the expression Oracle must search.
   A normal index on patient_id stores the original numeric patient_id values.
   The query asks for TO_CHAR(patient_id), which is a transformed expression.
   Therefore, Oracle cannot directly use the normal index on patient_id.

c) Rewrite the query so the function is not applied to the column:
   SELECT *
   FROM patient_visits
   WHERE patient_id = 5432;

   Or:
   SELECT *
   FROM patient_visits
   WHERE patient_id = TO_NUMBER('5432');

   The function is now applied to the constant, not the indexed column.

Optional advanced solution:
A function-based index could be created:
CREATE INDEX idx_pv_patient_id_char ON patient_visits(TO_CHAR(patient_id));

But in this case, the cleaner solution is to compare patient_id as a number.
*/


-- ============================================================
-- EXERCISE 5 — Discussion: real-world scenarios
-- ============================================================
-- For each scenario, decide:
-- a) Would you add an index?
-- b) On which column(s)?
-- c) Any concerns?
-- ============================================================

/*
Scenario A:
A reporting table gets loaded once per night by batch ETL.
During the day, analysts run SELECT queries by date range.
The table has 50 million rows.
Question: Index on date? Yes or no, and why?

Answer:
Yes, add an index on the date column used by the reports.
Example:
CREATE INDEX idx_reporting_date ON reporting_table(report_date);

Reason:
The table is very large and analysts frequently filter by date range.
Since data is loaded once per night and queried heavily during the day, the read benefit
usually justifies the index maintenance cost.

Concern:
The nightly ETL load may be slower because Oracle must maintain the index.
For a 50 million row reporting table, date partitioning could also be considered.
*/

/*
Scenario B:
An OLTP orders table gets 10,000 inserts per minute.
Support staff look up orders by customer_id or order_status.
order_status has 4 values: pending, processing, shipped, cancelled.
Question: What indexes would you add?

Answer:
Add an index on customer_id:
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

Reason:
customer_id is likely higher cardinality and useful for selective lookups.

Be careful with order_status:
A single-column B-tree index on order_status may not help much because it has only 4 values.
That is low cardinality.

Possible composite indexes depending on query patterns:
CREATE INDEX idx_orders_customer_status ON orders(customer_id, order_status);
CREATE INDEX idx_orders_status_date ON orders(order_status, order_date);

Concern:
This is a heavy OLTP table with 10,000 inserts per minute.
Too many indexes will slow down inserts, updates, and deletes.
Avoid unnecessary indexes and avoid bitmap indexes for high-concurrency OLTP workloads.
*/

/*
Scenario C:
A patient table has an email column, unique per patient.
There are 5 million patients.
The app frequently does:
WHERE email = 'user@example.com'
Question: What kind of index would be best?

Answer:
Use a unique B-tree index or, better, a unique constraint.

Option 1:
CREATE UNIQUE INDEX idx_patient_email ON patients(email);

Option 2, usually better because it enforces the business rule:
ALTER TABLE patients
ADD CONSTRAINT uq_patients_email UNIQUE (email);

Reason:
email is unique, the table is large, and the app frequently searches by equality.
Oracle can use an INDEX UNIQUE SCAN for this kind of lookup.
*/
