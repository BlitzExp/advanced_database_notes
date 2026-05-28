from sentence_transformers import SentenceTransformer
import wikipediaapi
import re
import textwrap

print("Libraries loaded ✓")

# ── CHANGE THIS: pick 1, 2, or 3 ──
ARTICLE_CHOICE = 3

ARTICLES = {
    1: "Vector database",
    2: "Word embedding",
    3: "Semantic search",
}

ARTICLE_TITLE = ARTICLES[ARTICLE_CHOICE]
print(f"You chose: '{ARTICLE_TITLE}'")

wiki = wikipediaapi.Wikipedia(
    user_agent="oracle-vector-search-lesson/1.0",
    language="en"
)

page = wiki.page(ARTICLE_TITLE)
if not page.exists():
    raise ValueError(f"Article '{ARTICLE_TITLE}' not found on Wikipedia")

print(f"✓ Fetched: {page.title}")
print(f"  Length: {len(page.text):,} characters")

# Split into paragraphs, filter short/empty ones
raw_paragraphs = [p.strip() for p in page.text.split('\n') if len(p.strip()) > 120]

# Truncate to 400 chars max per chunk (fits Oracle VARCHAR2(2000) safely)
chunks = []
for i, para in enumerate(raw_paragraphs[:30]):   # cap at 30 chunks for this lesson
    chunk = para[:400]
    # Remove references like [1], [23]
    chunk = re.sub(r'\[\d+\]', '', chunk).strip()
    if len(chunk) > 80:
        chunks.append(chunk)

print(f"  Chunks: {len(chunks)}")
print()
print("Preview of first 3 chunks:")
for i, c in enumerate(chunks[:3]):
    print(f"  [{i+1}] {c[:100]}...")

    # Load the model (downloads ~90MB on first run)
model = SentenceTransformer("all-MiniLM-L6-v2")
print("Model loaded ✓")

# Encode all chunks
embeddings = model.encode(chunks, show_progress_bar=True)
print(f"\nGenerated {len(embeddings)} embeddings, each with {len(embeddings[0])} dimensions")

setup_sql = """-- ============================================================
-- Lesson 02 Step 5: Create the doc_chunks table
-- Run this in freesql.com BEFORE loading data
-- ============================================================

-- Drop if it already exists from a previous run
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE doc_chunks';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE doc_chunks (
    chunk_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doc_name     VARCHAR2(200),
    chunk_text   VARCHAR2(2000),
    chunk_vector VECTOR(384, FLOAT32)
);

-- Verify
SELECT table_name FROM user_tables WHERE table_name = 'DOC_CHUNKS';
"""

print(setup_sql)
print("=" * 60)
print("📋 Copy everything above and run it in freesql.com")

def format_vector(embedding):
    """Format embedding as Oracle VECTOR literal, split to avoid ORA-01704."""
    values = ", ".join(f"{v:.8f}" for v in embedding)
    full = f"[{values}]"
    mid = len(full) // 2
    split_pos = full.rindex(',', 0, mid) + 1
    part1 = full[:split_pos]
    part2 = full[split_pos:]
    return f"TO_VECTOR(TO_CLOB('{part1}') || '{part2}', 384, FLOAT32)"

print("-- ============================================================")
print(f"-- Lesson 02: Vector embeddings from '{ARTICLE_TITLE}'")
print("-- Run in freesql.com AFTER Step 5 (table must exist)")
print("-- ============================================================")
print()
for chunk, embedding in zip(chunks, embeddings):
    safe_text = chunk.replace("'", "''")[:390]   # stay under VARCHAR2(2000)
    vec = format_vector(embedding)
    print(f"INSERT INTO doc_chunks (doc_name, chunk_text, chunk_vector)")
    print(f"VALUES ('{ARTICLE_TITLE[:50]}', '{safe_text}', {vec});")
    print()
print("COMMIT;")
print()
print(f"-- Verify: {len(chunks)} rows expected")
print("SELECT COUNT(*) FROM doc_chunks;")

MY_QUESTION = "How does semantic search work?"
TOP_N = 3

q_emb = model.encode([MY_QUESTION])[0]
q_vec = format_vector(q_emb)

print(f"-- Search query: {MY_QUESTION}")
print(f"-- Top {TOP_N} most similar chunks")
print()
print("SELECT")
print("    chunk_id,")
print("    SUBSTR(chunk_text, 1, 100) AS preview,")
print(f"    ROUND(VECTOR_DISTANCE(chunk_vector, {q_vec}, COSINE), 4) AS similarity_score")
print("FROM doc_chunks")
print("ORDER BY similarity_score ASC")
print(f"FETCH FIRST {TOP_N} ROWS ONLY;")