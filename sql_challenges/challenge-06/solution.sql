-- Challenge 6
-- Improve and automate the House-o-Pets database system by adding triggers.

--Create Table:

CREATE TABLE PET_CARE_LOG (
    PRODUCT_ID NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    LOG_DATE_TIME DATE DEFAULT SYSDATE,
    CREATED_BY_USER  VARCHAR2(30),
    LOG_TEXT  VARCHAR2(500),
    LAST_UPDATE_DATETIME  DATE,
    UPDATE_DATE DATE,
    UPDATED_BY_USER VARCHAR2(30)
)

-- Create a trigger that fires before inserting each row in the PET_CARE_LOG table. 
-- The trigger will assign the current data and time to the UPDATE_DATE column. 
-- It will also assign the current user to the UPDATED_BY_USER column. Use pseudocolumns to get the values that you need. 
-- Handle all errors in one general exception handler and send an error message using the RAISE_APPLICATION_ERROR procedure.
CREATE OR REPLACE TRIGGER pet_care_log_insert_trigger
BEFORE INSERT ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    :NEW.UPDATE_DATE := SYSDATE;
    :NEW.UPDATED_BY_USER := USER;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred while inserting a row into PET_CARE_LOG: ' || SQLERRM);
END;
/




-- Create a trigger that fires before updating each row of the PET_CARE_LOG table. 
-- This trigger will look at the current user and compare it with the value in the UPDATED_BY_USER column. 
-- If the two are the same, the update proceeds. If they are different, the update raises an exception and fails. 
-- Handle any other database errors the same way you did in the insert trigger.

CREATE OR REPLACE TRIGGER pet_care_log_update_trigger
BEFORE UPDATE ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    IF USER != :OLD.UPDATED_BY_USER THEN
        RAISE_APPLICATION_ERROR(-20002, 'You are not authorized to update this row. Only the user who created it can update it.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred while inserting a row into PET_CARE_LOG: ' || SQLERRM);
END;
/


--  Create a trigger that fires before any row is deleted from the PET_CARE_LOG table. 
-- This trigger looks at the user who is deleting the row. 
-- If the user is ‘JOEMANAGER,’ the delete continues successfully. Otherwise, the delete fails and sends an error message. 
-- Handle any other database errors the same way you did in the insert trigger.

CREATE OR REPLACE TRIGGER pet_care_log_delete_trigger
BEFORE DELETE ON PET_CARE_LOG
FOR EACH ROW
BEGIN
    IF USER != 'JOEMANAGER' THEN
        RAISE_APPLICATION_ERROR(-20003, 'You are not authorized to delete this row. Only JOEMANAGER can delete rows from this table.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred while inserting a row into PET_CARE_LOG: ' || SQLERRM);
END;
/