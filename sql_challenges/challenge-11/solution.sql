-- ============================================================
-- EXERCISE 1: Explore your schema
-- ============================================================
-- Question:
-- List all the objects in your schema using USER_OBJECTS.
-- Group by OBJECT_TYPE and count them.
-- Which object types do you have?
--
-- Answer:
-- USER_OBJECTS shows the objects owned by your current schema.
-- Common object types include TABLE, INDEX, VIEW, SEQUENCE, PROCEDURE,
-- FUNCTION, PACKAGE, TRIGGER, and SYNONYM.
-- The exact result depends on the objects currently created in your account.
-- ============================================================

-- Count objects by type
SELECT object_type, COUNT(*) AS cnt
FROM user_objects
GROUP BY object_type
ORDER BY object_type;

-- Detailed object list
SELECT object_name, object_type, created, last_ddl_time
FROM user_objects
ORDER BY object_type, object_name;

-- Optional: Show only valid/invalid status
SELECT object_type, status, COUNT(*) AS cnt
FROM user_objects
GROUP BY object_type, status
ORDER BY object_type, status;

-- Expected answer:
-- The query returns the types of schema objects you currently have.
-- For example, you may see TABLE, INDEX, PROCEDURE, FUNCTION, or VIEW.
-- This is the first step in documenting a schema before backup or migration.


-- ============================================================
-- EXERCISE 2: Basic GET_DDL
-- ============================================================
-- Question:
-- Use DBMS_METADATA.GET_DDL to extract DDL for one table or all tables.
-- Identify the key parts in the output.
--
-- Answer:
-- DBMS_METADATA.GET_DDL returns the CREATE statement for database objects.
-- For tables, the key parts are column definitions, data types, NULL/NOT NULL
-- rules, primary keys, foreign keys, check constraints, and optional storage
-- or tablespace settings.
-- ============================================================

-- First, set transform parameters for clean output
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/

-- Option A:
-- Get DDL for one actual table.
-- Replace MY_TABLE with one of your real table names from USER_TABLES.
SELECT DBMS_METADATA.GET_DDL('TABLE', 'MY_TABLE')
FROM dual;

-- Option B:
-- Get DDL for the first table in your schema.
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
WHERE ROWNUM = 1;

-- Option C:
-- Get DDL for all tables in your schema.
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
ORDER BY table_name;

-- Expected answer:
-- The output will contain CREATE TABLE statements.
-- Identify:
-- 1. Column definitions: name, type, precision/scale, NULL/NOT NULL
-- 2. Constraints: PRIMARY KEY, FOREIGN KEY, CHECK, UNIQUE
-- 3. Optional physical details: storage, tablespace, segment attributes
-- In this exercise, storage and tablespace details are disabled for portability.


-- ============================================================
-- EXERCISE 3: Clean DDL for portability
-- ============================================================
-- Question:
-- Remove schema names from DDL so it works in any schema.
-- Compare output with and without EMIT_SCHEMA.
--
-- Answer:
-- EMIT_SCHEMA controls whether exported DDL includes the original schema name.
-- For migration to a different schema, set EMIT_SCHEMA to false so DDL is
-- portable.
-- ============================================================

-- Clean portable DDL settings
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'EMIT_SCHEMA', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/

-- Try it on one table
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
WHERE ROWNUM = 1;

-- Expected comparison:
-- With EMIT_SCHEMA default:
--   CREATE TABLE "SCHEMA_OLD"."ORDERS" ...
--
-- With EMIT_SCHEMA = false:
--   CREATE TABLE "ORDERS" ...
--
-- Expected answer:
-- Setting EMIT_SCHEMA to false makes the DDL easier to run in another schema
-- because it avoids hardcoding the original owner name.


-- ============================================================
-- EXERCISE 4: Plan a migration
-- ============================================================
-- Question:
-- You are moving to a new schema with a different name.
-- What changes would you need to make to your exported DDL?
--
-- Scenario:
-- Migrating from SCHEMA_OLD to SCHEMA_NEW.
--
-- Answer:
-- You should remove or replace schema-qualified names, review foreign keys,
-- remove environment-specific storage details, and reload objects in the
-- correct dependency order.
-- ============================================================

-- 1. Identify table DDL that may contain schema names.
-- Replace ANY_TABLE_WITH_FK with an actual table name if you have one.
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
WHERE table_name = 'ANY_TABLE_WITH_FK';

-- 2. Check for foreign keys in your schema.
SELECT constraint_name, table_name, r_constraint_name
FROM user_constraints
WHERE constraint_type = 'R'
ORDER BY table_name, constraint_name;

-- 3. More detailed FK information.
SELECT 
    fk.constraint_name        AS fk_name,
    fk.table_name             AS child_table,
    pk.table_name             AS parent_table,
    pk.constraint_name        AS parent_constraint
FROM user_constraints fk
JOIN user_constraints pk
    ON fk.r_constraint_name = pk.constraint_name
WHERE fk.constraint_type = 'R'
ORDER BY child_table, fk_name;

-- Migration checklist answer:
-- 1. Export DDL with EMIT_SCHEMA = false.
-- 2. Search for schema-qualified references like "SCHEMA_OLD"."TABLE_NAME".
-- 3. Replace SCHEMA_OLD with SCHEMA_NEW only when references must remain qualified.
-- 4. Review foreign key REFERENCES clauses.
-- 5. Remove storage, tablespace, and segment attributes unless required.
-- 6. Reload in order:
--      a. Tables
--      b. Sequences
--      c. Constraints
--      d. Indexes
--      e. Views
--      f. Procedures, functions, packages
--      g. Triggers
-- 7. Recompile invalid objects.
-- 8. Verify object counts and sample queries.


-- ============================================================
-- EXERCISE 5: Dependency order
-- ============================================================
-- Question:
-- Look at USER_DEPENDENCIES to understand object relationships.
-- Use this to know which objects must be created first during restore.
--
-- Answer:
-- Objects that are referenced by others should usually be created first.
-- Tables usually come before views, procedures, functions, packages, and
-- triggers. Package specifications usually come before package bodies.
-- Foreign keys may need to be added after parent and child tables exist.
-- ============================================================

-- See all dependencies in your schema
SELECT referenced_name, referencing_name, referencing_type
FROM user_dependencies
ORDER BY referenced_name, referencing_name;

-- Find objects that depend on tables
SELECT referencing_name, referencing_type
FROM user_dependencies
WHERE referenced_name IN (
  SELECT table_name FROM user_tables
)
ORDER BY referencing_type, referencing_name;

-- Find direct dependencies for a specific object.
-- Replace PROC_NAME with an actual procedure/function/package name.
SELECT referenced_name, referenced_type
FROM user_dependencies
WHERE referencing_name = 'PROC_NAME';

-- Build a dependency summary for PL/SQL objects
SELECT referencing_name, referencing_type,
       LISTAGG(referenced_name, ', ') WITHIN GROUP (ORDER BY referenced_name) AS dependencies
FROM user_dependencies
WHERE referencing_type IN ('PACKAGE', 'PROCEDURE', 'FUNCTION')
GROUP BY referencing_name, referencing_type
ORDER BY referencing_type, referencing_name;

-- Expected answer:
-- USER_DEPENDENCIES helps decide reload order.
-- Example:
-- If a procedure references a table, create the table first.
-- If a view references a table, create the table first.
-- If foreign keys connect tables, create the tables first and add/enable
-- foreign keys after both parent and child tables exist.


-- ============================================================
-- EXERCISE 6: Design your own backup strategy
-- ============================================================
-- Question:
-- Given:
--   - No expdp access
--   - No directory privileges
--   - Need to move your schema to another database
--   - Only have SQL access
--
-- Design the steps you would take.
--
-- Answer:
-- Use SQL data dictionary views and DBMS_METADATA to manually document,
-- extract, clean, reload, and verify the schema.
-- ============================================================

-- STEP 1: Document current schema structure.
SELECT object_type, COUNT(*) AS cnt
FROM user_objects
GROUP BY object_type
ORDER BY object_type;

SELECT table_name, num_rows
FROM user_tables
ORDER BY num_rows DESC NULLS LAST;

-- STEP 2: Configure clean DDL extraction.
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'EMIT_SCHEMA', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/

-- STEP 3: Extract all DDL.

-- Extract tables
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
ORDER BY table_name;

-- Extract indexes
SELECT DBMS_METADATA.GET_DDL('INDEX', index_name)
FROM user_indexes
ORDER BY index_name;

-- Extract views
SELECT DBMS_METADATA.GET_DDL('VIEW', view_name)
FROM user_views
ORDER BY view_name;

-- Extract sequences
SELECT DBMS_METADATA.GET_DDL('SEQUENCE', sequence_name)
FROM user_sequences
ORDER BY sequence_name;

-- Extract constraints
SELECT DBMS_METADATA.GET_DDL('CONSTRAINT', constraint_name)
FROM user_constraints
WHERE constraint_type IN ('P', 'U', 'R', 'C')
ORDER BY constraint_type, constraint_name;

-- Extract procedures
SELECT DBMS_METADATA.GET_DDL('PROCEDURE', object_name)
FROM user_objects
WHERE object_type = 'PROCEDURE'
ORDER BY object_name;

-- Extract functions
SELECT DBMS_METADATA.GET_DDL('FUNCTION', object_name)
FROM user_objects
WHERE object_type = 'FUNCTION'
ORDER BY object_name;

-- Extract packages
SELECT DBMS_METADATA.GET_DDL('PACKAGE', object_name)
FROM user_objects
WHERE object_type = 'PACKAGE'
ORDER BY object_name;

-- Extract triggers
SELECT DBMS_METADATA.GET_DDL('TRIGGER', trigger_name)
FROM user_triggers
ORDER BY trigger_name;

-- STEP 4: Verify everything transferred.
SELECT object_type, COUNT(*) AS cnt
FROM user_objects
GROUP BY object_type
ORDER BY object_type;

SELECT table_name, num_rows
FROM user_tables
ORDER BY table_name;

SELECT index_name, table_name
FROM user_indexes
ORDER BY index_name;

SELECT object_name, object_type, status
FROM user_objects
WHERE status <> 'VALID'
ORDER BY object_type, object_name;


