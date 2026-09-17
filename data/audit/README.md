# SPEC-006 data audit

```bash
cd data
uv sync

# D1 — Shamela4_Full_DB (pinned revision)
uv run python audit/audit_d1.py --revision 07554bee488a12955dd5231d08487ae7ce767d1e

# D2–D4 — PDF libraries (+ D1×D2 overlap; needs D1 book_metadata.parquet)
uv run python audit/audit_pdfs.py

# Outputs land in audit/out/ (committed text/TSV/JSON).
```

Total download budget for a full audit pass: **< 2 GB**.
