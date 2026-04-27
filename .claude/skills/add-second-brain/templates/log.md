# Log

Append-only хронология всех операций над вики. Формат:

```
## [YYYY-MM-DD] <op> | <title>
```

где `op` ∈ `{ingest, query, lint, note, milestone, journal, digest, reflect, research}`.

Парсится одной командой:

```bash
grep "^## \[" log.md | tail -10
```

Используй inline-теги из `tags.md` (`#DECISION`, `#MILESTONE`, `#PROBLEM`, etc.) когда уместно.

---

## [DATE_PLACEHOLDER] note | Wiki создана через /add-second-brain v1.0.0
