-- ============================================================
-- EXERCISE 1: Manual transaction warm-up
-- ============================================================
-- Question:
-- Transfer $50 from Charlie (3) to Alice (1) using BEGIN / COMMIT manually.
-- Before: verify balances. After COMMIT: verify again.
--
-- Answer:
-- Use two UPDATE statements inside one transaction. Then COMMIT only after
-- both updates succeed.
-- ============================================================

-- Before transfer
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Transfer $50 from Charlie to Alice
BEGIN
    UPDATE accounts
    SET balance = balance - 50
    WHERE account_id = 3;

    UPDATE accounts
    SET balance = balance + 50
    WHERE account_id = 1;

    COMMIT;
END;
/

-- After transfer
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Expected after Exercise 1:
-- Alice   = 1050.00
-- Bob     = 500.00
-- Charlie = 200.00


-- ============================================================
-- EXERCISE 2: Catch yourself with ROLLBACK
-- ============================================================
-- Question:
-- Start a transfer of $10,000 from Bob (2) to Charlie (3).
-- Before committing, check the balances. Does Bob have enough?
-- Use ROLLBACK to undo. Verify balances restored.
--
-- Answer:
-- Bob does not have enough money. The attempted update violates the idea
-- of a valid transfer, so the transaction should be rolled back.
-- ============================================================

-- Before attempted transfer
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Attempt transfer from Bob to Charlie
UPDATE accounts
SET balance = balance - 10000
WHERE account_id = 2;

UPDATE accounts
SET balance = balance + 10000
WHERE account_id = 3;

-- Check balances before committing
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Answer:
-- Bob does not have enough funds.
-- In this table, the CHECK constraint balance >= 0 may cause the first
-- UPDATE to fail immediately. If it does fail, Oracle rejects the invalid
-- balance and the transaction remains safe.

-- Undo the attempted transaction
ROLLBACK;

-- Verify balances are restored
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Expected after ROLLBACK:
-- Same balances as before Exercise 2.


-- ============================================================
-- EXERCISE 3: SAVEPOINT checkpoint
-- ============================================================
-- Question:
-- You need to:
-- 1. Add $25 to Alice's balance
-- 2. Set a savepoint
-- 3. Deduct $25 from Charlie's balance, wrong account
-- 4. Rollback to savepoint
-- 5. Deduct $25 from Bob's balance instead
-- 6. Commit
--
-- Answer:
-- SAVEPOINT lets you undo only part of a transaction instead of rolling
-- back everything.
-- ============================================================

-- Before transaction
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Step 1: Add $25 to Alice
UPDATE accounts
SET balance = balance + 25
WHERE account_id = 1;

-- Step 2: Create checkpoint
SAVEPOINT after_alice_deposit;

-- Step 3: Wrong deduction from Charlie
UPDATE accounts
SET balance = balance - 25
WHERE account_id = 3;

-- Check current state before rollback to savepoint
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Step 4: Undo only the wrong deduction from Charlie
ROLLBACK TO after_alice_deposit;

-- Step 5: Correct deduction from Bob
UPDATE accounts
SET balance = balance - 25
WHERE account_id = 2;

-- Step 6: Commit final transaction
COMMIT;

-- Verify final state
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Expected effect of Exercise 3:
-- Alice increases by 25.
-- Charlie is unchanged because we rolled back his deduction.
-- Bob decreases by 25.


-- ============================================================
-- EXERCISE 4: Write your own stored procedure
-- ============================================================
-- Question:
-- Create a procedure called deposit_funds(p_account_id, p_amount).
-- It should:
-- 1. Validate that p_amount > 0, raise error if not
-- 2. Add p_amount to the account balance
-- 3. COMMIT on success
-- 4. ROLLBACK + re-raise on any error
-- Test it with: EXEC deposit_funds(3, 75);
--
-- Answer:
-- The procedure validates the amount, updates the account, commits if
-- successful, and rolls back if anything fails.
-- ============================================================

CREATE OR REPLACE PROCEDURE deposit_funds(
    p_account_id IN NUMBER,
    p_amount     IN NUMBER
) AS
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Deposit amount must be greater than zero.');
    END IF;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_account_id;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Account not found: ' || p_account_id);
    END IF;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Deposit complete: $' || p_amount ||
                         ' into account ' || p_account_id);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Deposit failed. All changes rolled back.');
        RAISE;
END;
/

-- Test procedure
SET SERVEROUTPUT ON;

EXEC deposit_funds(3, 75);

-- Verify deposit
SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Optional error test: invalid amount
-- EXEC deposit_funds(3, -50);

-- Optional error test: account not found
-- EXEC deposit_funds(999, 50);


-- ============================================================
-- EXERCISE 5: Discussion
-- ============================================================

-- Q1:
-- You're building a patient appointment booking system.
-- A booking requires:
--   a) Reserve the time slot
--   b) Create the appointment record
--   c) Send a confirmation notification
-- Which of these should be inside the transaction? Which should be outside? Why?
--
-- Answer:
-- Reserving the time slot and creating the appointment record should be
-- inside the transaction because they are database changes that must stay
-- consistent. If one fails, the other should be rolled back.
--
-- Sending the confirmation notification should usually be outside the main
-- database transaction because external actions like email, SMS, or push
-- notifications cannot always be rolled back. A common design is to commit
-- the appointment first, then send the notification, or save a notification
-- job in a queue/table as part of the transaction.

-- Q2:
-- Your stored procedure calls COMMIT at the end.
-- A developer calls your procedure from inside their own larger transaction.
-- What problem does this create?
--
-- Answer:
-- The procedure commits not only its own work, but also any previous uncommitted
-- work in the caller's transaction. This removes control from the caller and
-- can make it impossible to roll back the larger operation as one unit.
-- Because of this, many real systems avoid COMMIT inside reusable procedures
-- and let the application or outer transaction decide when to commit.

-- Q3:
-- You have a function called calculate_copay() and a procedure called post_payment().
-- A colleague wants to use calculate_copay() inside a SELECT statement.
-- Can they? Can they do the same with post_payment()? Why or why not?
--
-- Answer:
-- A function can be used inside SELECT if it returns a value and does not
-- perform transaction control such as COMMIT or ROLLBACK.
--
-- A procedure cannot be used directly inside SELECT because procedures are
-- called to perform actions, not to return a value as part of a query.
-- Procedures are called with EXEC or CALL.