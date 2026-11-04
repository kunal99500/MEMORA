Initialize migrations after installing requirements:

```bash
alembic revision --autogenerate -m "initial schema"
alembic upgrade head
```

Review generated migrations before applying them to production. Local development currently bootstraps tables with SQLAlchemy `create_all`.
