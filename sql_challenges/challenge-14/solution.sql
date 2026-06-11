-- ============================================================
-- Lesson 08 — ETL + Data Warehouse
-- Compact Answers for Assignment History Exercise
-- Designed to fit 03_etl_pipeline.ipynb
-- ============================================================

-- NOTES SUMMARY:
-- This exercise applies ETL, assignment-history tracking, triggers, and a
-- small star schema. The main idea is that the OLTP table stores the current
-- ticket state, while ticket_assignments stores historical assignment windows.
-- The Colab ETL then gives creation credit to the agent assigned at created_at
-- and resolution credit to the agent assigned at resolved_at.

-- ============================================================
-- STEP 1 — Source Tables OLTP
-- ============================================================

BEGIN EXECUTE IMMEDIATE 'DROP TABLE fact_ticket_daily'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE dim_agent'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ticket_assignments'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE tickets'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE TABLE tickets (
    ticket_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title        VARCHAR2(200) NOT NULL,
    status       VARCHAR2(20) DEFAULT 'open' NOT NULL,
    priority     VARCHAR2(10) DEFAULT 'medium' NOT NULL,
    created_at   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    resolved_at  TIMESTAMP,
    assigned_to  NUMBER NOT NULL,
    CONSTRAINT chk_ticket_status CHECK (
        status IN ('open', 'in_progress', 'resolved', 'cancelled')
    ),
    CONSTRAINT chk_ticket_priority CHECK (
        priority IN ('low', 'medium', 'high', 'critical')
    )
);

CREATE TABLE ticket_assignments (
    assignment_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id     NUMBER NOT NULL REFERENCES tickets(ticket_id),
    assigned_to   NUMBER NOT NULL,
    assigned_by   NUMBER,
    valid_from    TIMESTAMP NOT NULL,
    valid_to      TIMESTAMP
);

CREATE INDEX idx_ticket_assignments_lookup
ON ticket_assignments(ticket_id, valid_from, valid_to);


-- ============================================================
-- STEP 3 — Trigger
-- Put this before sample data so inserts are logged automatically.
-- ============================================================

CREATE OR REPLACE TRIGGER trg_ticket_assignment_log
AFTER INSERT OR UPDATE OF assigned_to ON tickets
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO ticket_assignments (
            ticket_id, assigned_to, assigned_by, valid_from, valid_to
        )
        VALUES (
            :NEW.ticket_id,
            :NEW.assigned_to,
            NULL,
            :NEW.created_at,
            NULL
        );
    ELSIF UPDATING THEN
        UPDATE ticket_assignments
           SET valid_to = SYSTIMESTAMP
         WHERE ticket_id = :OLD.ticket_id
           AND valid_to IS NULL;

        INSERT INTO ticket_assignments (
            ticket_id, assigned_to, assigned_by, valid_from, valid_to
        )
        VALUES (
            :NEW.ticket_id,
            :NEW.assigned_to,
            NULL,
            SYSTIMESTAMP,
            NULL
        );
    END IF;
END;
/


-- ============================================================
-- STEP 2 — Sample Data
-- At least 5 tickets. Ticket 2 is reassigned.
-- ============================================================

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES (
    'Password reset not working',
    'resolved',
    'high',
    SYSTIMESTAMP - INTERVAL '5' DAY,
    SYSTIMESTAMP - INTERVAL '4' DAY,
    1
);

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES (
    'Cannot access billing page',
    'in_progress',
    'critical',
    SYSTIMESTAMP - INTERVAL '3' DAY,
    NULL,
    2
);

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES (
    'Email notification delay',
    'resolved',
    'medium',
    SYSTIMESTAMP - INTERVAL '2' DAY,
    SYSTIMESTAMP - INTERVAL '1' DAY,
    3
);

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES (
    'UI alignment issue',
    'open',
    'low',
    SYSTIMESTAMP - INTERVAL '1' DAY,
    NULL,
    4
);

INSERT INTO tickets (title, status, priority, created_at, resolved_at, assigned_to)
VALUES (
    'API timeout error',
    'resolved',
    'high',
    SYSTIMESTAMP - INTERVAL '6' DAY,
    SYSTIMESTAMP - INTERVAL '5' DAY,
    2
);

COMMIT;

-- Test reassignment:
-- Ticket 2 starts assigned to agent 2, then moves to agent 4.
UPDATE tickets
SET assigned_to = 4
WHERE ticket_id = 2;

COMMIT;

-- Resolve ticket 2 after reassignment.
UPDATE tickets
SET status = 'resolved',
    resolved_at = SYSTIMESTAMP
WHERE ticket_id = 2;

COMMIT;

-- Verify assignment history.
SELECT ta.ticket_id,
       t.title,
       ta.assigned_to,
       ta.valid_from,
       ta.valid_to,
       CASE WHEN ta.valid_to IS NULL THEN 'current' ELSE 'historical' END AS assignment_status
FROM ticket_assignments ta
JOIN tickets t ON t.ticket_id = ta.ticket_id
ORDER BY ta.ticket_id, ta.valid_from;


-- ============================================================
-- STEP 4 — Data Warehouse Tables Star Schema
-- ============================================================

CREATE TABLE dim_agent (
    agent_key   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agent_id    NUMBER NOT NULL UNIQUE,
    agent_name  VARCHAR2(100) NOT NULL,
    team        VARCHAR2(50) NOT NULL
);

CREATE TABLE fact_ticket_daily (
    fact_key          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key          NUMBER NOT NULL,
    agent_key         NUMBER NOT NULL REFERENCES dim_agent(agent_key),
    status            VARCHAR2(20) NOT NULL,
    priority          VARCHAR2(10) NOT NULL,
    tickets_created   NUMBER DEFAULT 0,
    tickets_resolved  NUMBER DEFAULT 0,
    CONSTRAINT uq_fact_ticket_daily UNIQUE (
        date_key, agent_key, status, priority
    )
);


-- ============================================================
-- STEP 5 — Populate dim_agent
-- ============================================================

INSERT INTO dim_agent (agent_id, agent_name, team)
VALUES (1, 'Ana Support', 'Tier 1');

INSERT INTO dim_agent (agent_id, agent_name, team)
VALUES (2, 'Bruno Support', 'Tier 1');

INSERT INTO dim_agent (agent_id, agent_name, team)
VALUES (3, 'Carla Support', 'Billing');

INSERT INTO dim_agent (agent_id, agent_name, team)
VALUES (4, 'Diego Support', 'Escalations');

COMMIT;

SELECT * FROM dim_agent ORDER BY agent_id;


-- ============================================================
-- STEP 6 — ETL Logic for Colab
-- Paste this into your 03_etl_pipeline.ipynb after the connection cell.
-- ============================================================

/*
# === EXTRACT ===
tickets_df = pd.read_sql("SELECT * FROM tickets ORDER BY ticket_id", engine)
assignments_df = pd.read_sql(
    "SELECT * FROM ticket_assignments ORDER BY ticket_id, valid_from",
    engine
)
agents_df = pd.read_sql("SELECT * FROM dim_agent ORDER BY agent_id", engine)

print(f"Tickets: {len(tickets_df)}")
print(f"Assignments: {len(assignments_df)}")
display(tickets_df)
display(assignments_df)


# === TRANSFORM: helper to find historical assignee ===
def assignee_at(ticket_id, event_time):
    if pd.isna(event_time):
        return None

    rows = assignments_df[
        (assignments_df["ticket_id"] == ticket_id) &
        (assignments_df["valid_from"] <= event_time) &
        (
            assignments_df["valid_to"].isna() |
            (assignments_df["valid_to"] > event_time)
        )
    ]

    if rows.empty:
        return None

    return int(rows.iloc[-1]["assigned_to"])


# Creation credit: agent assigned at created_at
created_events = tickets_df.copy()
created_events["event_date"] = created_events["created_at"].dt.date
created_events["agent_id"] = created_events.apply(
    lambda r: assignee_at(r["ticket_id"], r["created_at"]),
    axis=1
)
created_events["tickets_created"] = 1
created_events["tickets_resolved"] = 0

# Resolution credit: agent assigned at resolved_at
resolved_events = tickets_df[tickets_df["resolved_at"].notna()].copy()
resolved_events["event_date"] = resolved_events["resolved_at"].dt.date
resolved_events["agent_id"] = resolved_events.apply(
    lambda r: assignee_at(r["ticket_id"], r["resolved_at"]),
    axis=1
)
resolved_events["tickets_created"] = 0
resolved_events["tickets_resolved"] = 1

# Keep only needed columns
created_fact = created_events[
    ["event_date", "agent_id", "status", "priority",
     "tickets_created", "tickets_resolved"]
]

resolved_fact = resolved_events[
    ["event_date", "agent_id", "status", "priority",
     "tickets_created", "tickets_resolved"]
]

fact_events = pd.concat([created_fact, resolved_fact], ignore_index=True)
fact_events = fact_events.dropna(subset=["agent_id"])
fact_events["agent_id"] = fact_events["agent_id"].astype(int)
fact_events["date_key"] = fact_events["event_date"].apply(
    lambda d: int(d.strftime("%Y%m%d"))
)

fact_grouped = (
    fact_events
    .groupby(["date_key", "agent_id", "status", "priority"], as_index=False)
    .agg({
        "tickets_created": "sum",
        "tickets_resolved": "sum"
    })
)

# Map source agent_id to warehouse surrogate agent_key
fact_grouped = fact_grouped.merge(
    agents_df[["agent_key", "agent_id"]],
    on="agent_id",
    how="left"
)

display(fact_grouped)


# === LOAD ===
raw_connection = engine.raw_connection()
cursor = raw_connection.cursor()

fact_insert_sql = """
    MERGE INTO fact_ticket_daily f
    USING (
        SELECT :1 AS date_key,
               :2 AS agent_key,
               :3 AS status,
               :4 AS priority,
               :5 AS tickets_created,
               :6 AS tickets_resolved
        FROM dual
    ) src
    ON (
        f.date_key = src.date_key
        AND f.agent_key = src.agent_key
        AND f.status = src.status
        AND f.priority = src.priority
    )
    WHEN NOT MATCHED THEN INSERT (
        date_key, agent_key, status, priority,
        tickets_created, tickets_resolved
    )
    VALUES (
        src.date_key, src.agent_key, src.status, src.priority,
        src.tickets_created, src.tickets_resolved
    )
    WHEN MATCHED THEN UPDATE SET
        tickets_created = src.tickets_created,
        tickets_resolved = src.tickets_resolved
"""

for _, row in fact_grouped.iterrows():
    cursor.execute(fact_insert_sql, [
        int(row["date_key"]),
        int(row["agent_key"]),
        row["status"],
        row["priority"],
        int(row["tickets_created"]),
        int(row["tickets_resolved"])
    ])

raw_connection.commit()
cursor.close()
raw_connection.close()

print("Loaded fact_ticket_daily successfully.")
*/


-- ============================================================
-- STEP 7 — Verify
-- The reassigned ticket should show original agent for creation
-- and new agent for resolution.
-- ============================================================

SELECT TO_DATE(TO_CHAR(f.date_key), 'YYYYMMDD') AS fact_date,
       a.agent_name,
       a.team,
       f.status,
       f.priority,
       f.tickets_created,
       f.tickets_resolved
FROM fact_ticket_daily f
JOIN dim_agent a ON a.agent_key = f.agent_key
ORDER BY fact_date, a.agent_name, f.status, f.priority;


-- ============================================================
-- COLAB GRAPH
-- Paste after the Step 7 query in Colab.
-- ============================================================

/*
query = """
SELECT TO_DATE(TO_CHAR(f.date_key), 'YYYYMMDD') AS fact_date,
       a.agent_name,
       a.team,
       f.status,
       f.priority,
       f.tickets_created,
       f.tickets_resolved
FROM fact_ticket_daily f
JOIN dim_agent a ON a.agent_key = f.agent_key
ORDER BY fact_date, a.agent_name, f.status, f.priority
"""

df_fact = pd.read_sql(query, engine)
df_fact["fact_date"] = pd.to_datetime(df_fact["fact_date"])

df_long = df_fact.melt(
    id_vars=["fact_date", "agent_name", "team", "status", "priority"],
    value_vars=["tickets_created", "tickets_resolved"],
    var_name="metric",
    value_name="ticket_count"
)

fig = px.bar(
    df_long,
    x="fact_date",
    y="ticket_count",
    color="agent_name",
    facet_row="metric",
    hover_data=["team", "status", "priority"],
    title="Tickets Created and Resolved per Agent per Day"
)

fig.show()
*/