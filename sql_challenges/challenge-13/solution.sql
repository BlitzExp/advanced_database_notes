-- ============================================================
-- EXERCISE 1 — Team Velocity
-- ============================================================
-- Contract:
-- Velocity = completed tasks per team member per day.
-- Uses completed tasks only. Window = min to max created_at in TASKS.
-- Unit = completed tasks / member / day.
-- Edge case: teams with fewer people are normalized by team member count.

WITH window_days AS (
    SELECT GREATEST(MAX(TRUNC(created_at)) - MIN(TRUNC(created_at)) + 1, 1) AS days_in_window
    FROM tasks
),
team_velocity AS (
    SELECT t.name AS team_name,
           COUNT(DISTINCT u.id) AS member_count,
           COUNT(CASE WHEN ts.status = 'completed' THEN ts.id END) AS completed_tasks,
           ROUND(
               COUNT(CASE WHEN ts.status = 'completed' THEN ts.id END)
               / NULLIF(COUNT(DISTINCT u.id), 0)
               / MAX(w.days_in_window),
               3
           ) AS velocity_per_member_per_day
    FROM teams t
    LEFT JOIN users u ON u.team_id = t.id
    LEFT JOIN tasks ts ON ts.assigned_to = u.id
    CROSS JOIN window_days w
    GROUP BY t.id, t.name
)
SELECT team_name,
       member_count,
       completed_tasks,
       velocity_per_member_per_day,
       CASE
           WHEN velocity_per_member_per_day < AVG(velocity_per_member_per_day) OVER ()
           THEN 'Below Average'
           ELSE 'At or Above Average'
       END AS velocity_flag
FROM team_velocity
ORDER BY velocity_per_member_per_day DESC;

-- Suggested Colab graph:
-- df = pd.read_sql(query, engine)
-- fig = px.bar(df, x="team_name", y="velocity_per_member_per_day",
--              color="velocity_flag", text="velocity_per_member_per_day",
--              title="Team Velocity")
-- fig.show()


-- ============================================================
-- EXERCISE 2 — On-Time Delivery Rate
-- ============================================================
-- Contract:
-- On-time = completed before the end of the due_date.
-- Uses completed tasks only, excludes tasks with NULL due_date/completed_at.
-- Unit = percentage by priority.
-- Edge case: completed at 23:59 on due date is on time; 00:01 next day is late.

SELECT priority,
       COUNT(*) AS completed_with_due_date,
       COUNT(CASE WHEN completed_at < CAST(due_date + 1 AS TIMESTAMP) THEN 1 END) AS on_time_tasks,
       ROUND(
           COUNT(CASE WHEN completed_at < CAST(due_date + 1 AS TIMESTAMP) THEN 1 END)
           * 100.0 / NULLIF(COUNT(*), 0),
           1
       ) AS on_time_delivery_rate_pct,
       ROUND(
           AVG(
               CASE
                   WHEN completed_at >= CAST(due_date + 1 AS TIMESTAMP)
                   THEN (CAST(completed_at AS DATE) - (due_date + 1)) * 24
               END
           ),
           1
       ) AS avg_lateness_hours
FROM tasks
WHERE status = 'completed'
  AND completed_at IS NOT NULL
  AND due_date IS NOT NULL
GROUP BY priority
ORDER BY CASE priority
             WHEN 'critical' THEN 1
             WHEN 'high' THEN 2
             WHEN 'medium' THEN 3
             WHEN 'low' THEN 4
         END;

-- Suggested Colab graph:
-- fig = px.bar(df, x="priority", y="on_time_delivery_rate_pct",
--              text="on_time_delivery_rate_pct", title="On-Time Delivery Rate by Priority")
-- fig.show()


-- ============================================================
-- EXERCISE 3 — Improved Tasks per Team
-- ============================================================
-- Contract:
-- total_tasks = all assigned tasks.
-- active_tasks = open + in_progress + blocked.
-- completion_rate = completed / total excluding cancelled.
-- health_score = workload label based on active task count.

WITH team_counts AS (
    SELECT t.name AS team_name,
           COUNT(ts.id) AS total_tasks,
           COUNT(CASE WHEN ts.status IN ('open', 'in_progress', 'blocked') THEN ts.id END) AS active_tasks,
           ROUND(
               COUNT(CASE WHEN ts.status = 'completed' THEN ts.id END)
               * 100.0
               / NULLIF(COUNT(CASE WHEN ts.status <> 'cancelled' THEN ts.id END), 0),
               1
           ) AS completion_rate_pct
    FROM teams t
    LEFT JOIN users u ON u.team_id = t.id
    LEFT JOIN tasks ts ON ts.assigned_to = u.id
    GROUP BY t.id, t.name
)
SELECT team_name,
       total_tasks,
       active_tasks,
       completion_rate_pct,
       CASE
           WHEN active_tasks > 10 THEN 'Overloaded'
           WHEN active_tasks BETWEEN 5 AND 10 THEN 'Healthy'
           ELSE 'Underutilized'
       END AS health_score
FROM team_counts
ORDER BY active_tasks DESC;

-- Suggested Colab graph:
-- fig = px.bar(df, x="team_name", y="active_tasks",
--              color="health_score", text="active_tasks",
--              title="Active Tasks per Team")
-- fig.show()


-- ============================================================
-- EXERCISE 4 — Improved Average Resolution Time
-- ============================================================
-- Contract:
-- Resolution time = completed_at - created_at in hours.
-- Shows average, median, fastest, slowest by priority.
-- Target SLA: critical 24h, high 72h, medium 168h, low 336h.

WITH completed AS (
    SELECT priority,
           EXTRACT(DAY FROM (completed_at - created_at)) * 24
           + EXTRACT(HOUR FROM (completed_at - created_at))
           + EXTRACT(MINUTE FROM (completed_at - created_at)) / 60 AS resolution_hours
    FROM tasks
    WHERE status = 'completed'
      AND completed_at IS NOT NULL
),
stats AS (
    SELECT priority,
           COUNT(*) AS completed_task_count,
           ROUND(AVG(resolution_hours), 1) AS avg_resolution_hours,
           ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_hours), 1) AS median_resolution_hours,
           ROUND(MIN(resolution_hours), 1) AS fastest_hours,
           ROUND(MAX(resolution_hours), 1) AS slowest_hours
    FROM completed
    GROUP BY priority
)
SELECT priority,
       completed_task_count,
       avg_resolution_hours,
       median_resolution_hours,
       fastest_hours,
       slowest_hours,
       CASE priority
           WHEN 'critical' THEN 24
           WHEN 'high' THEN 72
           WHEN 'medium' THEN 168
           WHEN 'low' THEN 336
       END AS sla_target_hours,
       CASE
           WHEN avg_resolution_hours <=
                CASE priority
                    WHEN 'critical' THEN 24
                    WHEN 'high' THEN 72
                    WHEN 'medium' THEN 168
                    WHEN 'low' THEN 336
                END
           THEN 'Target Met'
           ELSE 'Target Missed'
       END AS target_status,
       CASE
           WHEN completed_task_count < 3 THEN 'Small Sample'
           ELSE 'OK'
       END AS sample_note
FROM stats
ORDER BY CASE priority
             WHEN 'critical' THEN 1
             WHEN 'high' THEN 2
             WHEN 'medium' THEN 3
             WHEN 'low' THEN 4
         END;

-- Suggested Colab graph:
-- fig = px.bar(df, x="priority", y="avg_resolution_hours",
--              color="target_status", text="avg_resolution_hours",
--              title="Average Resolution Time by Priority")
-- fig.show()


-- ============================================================
-- EXERCISE 5 — Improved Overdue Tasks
-- ============================================================
-- Contract:
-- Overdue = due_date before today, task not completed/cancelled.
-- Shows owner, team, priority, days overdue, and severity.

WITH overdue AS (
    SELECT ts.title,
           NVL(u.full_name, 'Unassigned') AS assignee,
           NVL(t.name, 'No Team') AS team_name,
           ts.priority,
           ts.due_date,
           TRUNC(SYSDATE) - ts.due_date AS days_overdue,
           CASE
               WHEN ts.priority = 'critical' AND TRUNC(SYSDATE) - ts.due_date > 0 THEN 'CRITICAL'
               WHEN ts.priority = 'high'     AND TRUNC(SYSDATE) - ts.due_date > 2 THEN 'HIGH'
               WHEN ts.priority = 'medium'   AND TRUNC(SYSDATE) - ts.due_date > 5 THEN 'MEDIUM'
               ELSE 'LOW'
           END AS severity
    FROM tasks ts
    LEFT JOIN users u ON u.id = ts.assigned_to
    LEFT JOIN teams t ON t.id = u.team_id
    WHERE ts.due_date < TRUNC(SYSDATE)
      AND ts.status NOT IN ('completed', 'cancelled')
      AND ts.due_date IS NOT NULL
)
SELECT title,
       assignee,
       team_name,
       priority,
       due_date,
       days_overdue,
       severity
FROM overdue
ORDER BY CASE severity
             WHEN 'CRITICAL' THEN 1
             WHEN 'HIGH' THEN 2
             WHEN 'MEDIUM' THEN 3
             ELSE 4
         END,
         days_overdue DESC;

-- Summary by severity:
WITH overdue AS (
    SELECT TRUNC(SYSDATE) - due_date AS days_overdue,
           CASE
               WHEN priority = 'critical' AND TRUNC(SYSDATE) - due_date > 0 THEN 'CRITICAL'
               WHEN priority = 'high'     AND TRUNC(SYSDATE) - due_date > 2 THEN 'HIGH'
               WHEN priority = 'medium'   AND TRUNC(SYSDATE) - due_date > 5 THEN 'MEDIUM'
               ELSE 'LOW'
           END AS severity
    FROM tasks
    WHERE due_date < TRUNC(SYSDATE)
      AND status NOT IN ('completed', 'cancelled')
      AND due_date IS NOT NULL
)
SELECT NVL(severity, 'TOTAL') AS severity,
       COUNT(*) AS overdue_count,
       ROUND(AVG(days_overdue), 1) AS avg_days_overdue
FROM overdue
GROUP BY ROLLUP(severity)
ORDER BY CASE NVL(severity, 'TOTAL')
             WHEN 'CRITICAL' THEN 1
             WHEN 'HIGH' THEN 2
             WHEN 'MEDIUM' THEN 3
             WHEN 'LOW' THEN 4
             ELSE 5
         END;

-- Suggested Colab graph:
-- fig = px.bar(df, x="title", y="days_overdue",
--              color="severity", hover_data=["assignee", "team_name", "priority"],
--              title="Overdue Tasks by Severity")
-- fig.show()


-- ============================================================
-- EXERCISE 6 — Fix Productivity Score
-- ============================================================
-- Problem:
-- Counting all assigned tasks is not productivity. It mixes open, completed,
-- cancelled, easy, and hard work.
-- Better metric:
-- completed weighted points per active day by user.

WITH completed AS (
    SELECT u.id,
           u.full_name,
           CASE ts.priority
               WHEN 'critical' THEN 4
               WHEN 'high' THEN 3
               WHEN 'medium' THEN 2
               WHEN 'low' THEN 1
           END AS priority_weight,
           TRUNC(ts.completed_at) AS completed_day
    FROM users u
    JOIN tasks ts ON ts.assigned_to = u.id
    WHERE ts.status = 'completed'
      AND ts.completed_at IS NOT NULL
),
user_scores AS (
    SELECT full_name,
           COUNT(*) AS completed_tasks,
           SUM(priority_weight) AS weighted_points,
           GREATEST(MAX(completed_day) - MIN(completed_day) + 1, 1) AS active_days
    FROM completed
    GROUP BY id, full_name
)
SELECT full_name,
       completed_tasks,
       weighted_points,
       active_days,
       ROUND(weighted_points / NULLIF(active_days, 0), 2) AS weighted_completed_points_per_day
FROM user_scores
ORDER BY weighted_completed_points_per_day DESC;

-- Suggested Colab graph:
-- fig = px.bar(df, x="full_name", y="weighted_completed_points_per_day",
--              text="weighted_completed_points_per_day",
--              title="Weighted Productivity by User")
-- fig.show()


-- ============================================================
-- EXERCISE 7 — Fix Team Efficiency
-- ============================================================
-- Problem:
-- AVG(task_id) is meaningless because task IDs are identifiers, not values.
-- Better metric:
-- completed tasks / non-cancelled tasks by team.

SELECT t.name AS team_name,
       COUNT(ts.id) AS total_tasks,
       COUNT(CASE WHEN ts.status = 'completed' THEN ts.id END) AS completed_tasks,
       COUNT(CASE WHEN ts.status IN ('open', 'in_progress', 'blocked') THEN ts.id END) AS active_tasks,
       ROUND(
           COUNT(CASE WHEN ts.status = 'completed' THEN ts.id END)
           * 100.0
           / NULLIF(COUNT(CASE WHEN ts.status <> 'cancelled' THEN ts.id END), 0),
           1
       ) AS team_efficiency_pct
FROM teams t
LEFT JOIN users u ON u.team_id = t.id
LEFT JOIN tasks ts ON ts.assigned_to = u.id
GROUP BY t.id, t.name
ORDER BY team_efficiency_pct DESC;

-- Suggested Colab graph:
-- fig = px.bar(df, x="team_name", y="team_efficiency_pct",
--              text="team_efficiency_pct", title="Team Efficiency")
-- fig.show()


-- ============================================================
-- EXERCISE 8 — Fix Urgency Index
-- ============================================================
-- Problem:
-- priority is text, so it cannot be multiplied directly.
-- due_date is a date, so it should be converted into days until due.
-- Better metric:
-- priority weight * 10 - days_until_due.
-- If a task is overdue, days_until_due is negative, so urgency increases.

SELECT title,
       status,
       priority,
       due_date,
       CASE priority
           WHEN 'critical' THEN 4
           WHEN 'high' THEN 3
           WHEN 'medium' THEN 2
           WHEN 'low' THEN 1
       END AS priority_weight,
       due_date - TRUNC(SYSDATE) AS days_until_due,
       (
           CASE priority
               WHEN 'critical' THEN 4
               WHEN 'high' THEN 3
               WHEN 'medium' THEN 2
               WHEN 'low' THEN 1
           END * 10
       ) - NVL(due_date - TRUNC(SYSDATE), 0) AS urgency_score
FROM tasks
WHERE status NOT IN ('completed', 'cancelled')
ORDER BY urgency_score DESC;

-- Suggested Colab graph:
-- fig = px.bar(df.head(10), x="title", y="urgency_score",
--              color="priority", title="Top 10 Urgent Tasks")
-- fig.update_layout(xaxis_tickangle=-45)
-- fig.show()


-- ============================================================
-- COLAB NOTEBOOK EXTRA — Tasks Completed per Day
-- ============================================================
-- This matches the final exercise in the dashboard notebook.

SELECT TRUNC(completed_at) AS completion_date,
       COUNT(*) AS tasks_completed
FROM tasks
WHERE status = 'completed'
  AND completed_at IS NOT NULL
GROUP BY TRUNC(completed_at)
ORDER BY completion_date;

-- Suggested Colab graph:
-- query = """
-- SELECT TRUNC(completed_at) AS completion_date,
--        COUNT(*) AS tasks_completed
-- FROM tasks
-- WHERE status = 'completed'
--   AND completed_at IS NOT NULL
-- GROUP BY TRUNC(completed_at)
-- ORDER BY completion_date
-- """
-- df_completed_daily = pd.read_sql(query, engine)
-- df_completed_daily["completion_date"] = pd.to_datetime(df_completed_daily["completion_date"])
-- fig = px.line(df_completed_daily, x="completion_date", y="tasks_completed",
--               markers=True, title="Tasks Completed per Day")
-- fig.show()
