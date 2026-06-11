-- ============================================================
-- EXERCISE 1 — Model Design: Comment model
-- ============================================================

-- Questions / Answers:
-- 1. Comment should relate to one Task and one User.
-- 2. Yes, Task should have a comments relationship.
-- 3. If a task is deleted, its comments should usually be deleted too.

-- Paste this into the model cell after Task, or add it with the other models:

/*
from sqlalchemy import CheckConstraint

class Comment(Base):
    __tablename__ = "comments"

    id = Column(Integer, primary_key=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(String(1000), nullable=False)
    created_at = Column(DateTime, server_default=func.current_timestamp())

    __table_args__ = (
        CheckConstraint("TRIM(content) IS NOT NULL", name="ck_comments_content_not_empty"),
    )

    task = relationship("Task", back_populates="comments")
    user = relationship("User", back_populates="comments")
*/

-- Add these relationships to the existing classes:

/*
# Inside Task:
comments = relationship("Comment", back_populates="task", cascade="all, delete-orphan")

# Inside User:
comments = relationship("Comment", back_populates="user")
*/


-- ============================================================
-- EXERCISE 2 — Migration Creation
-- ============================================================

-- Use your existing Alembic setup cell, then run:

/*
command.revision(
    alembic_cfg,
    autogenerate=True,
    message="add comments table"
)

import glob

migration_files = sorted(glob.glob("/content/alembic/versions/*.py"))

for f in migration_files:
    print(f)

latest = migration_files[-1]

with open(latest) as f:
    print(f.read())
*/

-- Questions / Answers:
-- 1. upgrade() applies the change, so it creates the comments table.
-- 2. downgrade() reverses the change, so it drops the comments table.
-- 3. Downgrading removes the comments table and its data.

-- Bonus:
-- Add this to the generated migration inside op.create_table():
/*
sa.CheckConstraint("TRIM(content) IS NOT NULL", name="ck_comments_content_not_empty")
*/


-- ============================================================
-- EXERCISE 3 — CRUD Challenge
-- ============================================================

-- Before running the CRUD script, fix the Task model.
-- Move/add priority inside Task, not Team:

/*
# Inside Task:
priority = Column(String(20), default="medium")
*/

-- Then generate/apply a migration for the priority column if needed.

-- ORM-only CRUD solution:

/*
with Session(engine) as session:
    devops = Team(
        name="DevOps",
        description="Operations and deployment team"
    )

    diana = User(
        username="diana_ops",
        email="diana@example.com",
        full_name="Diana Ops",
        team=devops
    )

    task1 = Task(
        title="Configure CI pipeline",
        description="Create CI workflow",
        status="open",
        priority="high",
        assignee=diana
    )

    task2 = Task(
        title="Review deployment logs",
        description="Check deployment logs",
        status="open",
        priority="medium",
        assignee=diana
    )

    task3 = Task(
        title="Clean old artifacts",
        description="Remove old build files",
        status="open",
        priority="low",
        assignee=diana
    )

    session.add(devops)
    session.add_all([task1, task2, task3])
    session.commit()

    count = session.query(Task).filter(Task.assignee == diana).count()
    print(f"Task count for {diana.username}: {count}")

    task1.status = "closed"
    session.commit()
    print(f"Closed task: {task1.title}")

    session.delete(task3)
    session.commit()
    print(f"Deleted lowest priority task: {task3.title}")

    remaining = session.query(Task).filter(Task.assignee == diana).all()
    print("Remaining tasks:")
    for task in remaining:
        print(f"- {task.title} | {task.status} | {task.priority}")
*/


-- ============================================================
-- EXERCISE 4 — Migration Rollback
-- ============================================================

-- Use the rollback cell already in your notebook:

/*
command.downgrade(alembic_cfg, "-1")
print("✅ Downgraded by 1. New columns removed.")
*/

-- Questions / Answers:
-- 1. The bad column estimated_hours is removed.
-- 2. Any data stored in estimated_hours is lost after the column is dropped.


-- ============================================================
-- EXERCISE 5 — Concept Check
-- ============================================================

-- 1. Why use ORM instead of raw SQL?
-- ORM lets you work with Python objects instead of writing every query manually.

-- 2. Why use migrations?
-- Migrations version-control schema changes and make upgrades/rollbacks repeatable.

-- 3. When would you rollback?
-- When a migration is wrong, breaks the app, or adds an incorrect schema change.

-- 4. Difference between add() and commit()?
-- add() tracks an object in the session; commit() saves changes to the database.

-- 5. Why are relationships useful?
-- They let you navigate related records naturally, like user.tasks or task.comments.
