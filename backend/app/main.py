import logging
from sqlalchemy import inspect,text
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import get_settings
from app.db.base import Base
from app.db.session import engine
from app.models import entities  # noqa
from app.api.routes import router
s=get_settings();s.validate_security();logging.basicConfig(level=logging.INFO)
Base.metadata.create_all(bind=engine)  # Local bootstrap; use Alembic for production migrations.
chat_message_columns = {
    column['name'] for column in inspect(engine).get_columns('chat_messages')
}
if 'language' not in chat_message_columns:
    with engine.begin() as connection:
        connection.execute(text(
            "ALTER TABLE chat_messages ADD COLUMN language VARCHAR(35) NOT NULL DEFAULT ''"
        ))
if 'conversation_id' not in chat_message_columns:
    with engine.begin() as connection:
        connection.execute(text(
            "ALTER TABLE chat_messages ADD COLUMN conversation_id VARCHAR(64)"
        ))
capture_columns = {
    column['name'] for column in inspect(engine).get_columns('captures')
}
if 'timeline_id' not in capture_columns:
    with engine.begin() as connection:
        connection.execute(text(
            "ALTER TABLE captures ADD COLUMN timeline_id VARCHAR(64)"
        ))
    with engine.begin() as connection:
        connection.execute(text(
            "CREATE INDEX IF NOT EXISTS ix_captures_timeline_id "
            "ON captures (timeline_id)"
        ))
for index in entities.ChatMessage.__table__.indexes:
    if any(column.name == 'conversation_id' for column in index.columns):
        index.create(bind=engine, checkfirst=True)
app=FastAPI(title='MEMORA API',version='1.0.0',description='Evidence-first visual memory for Home and Business environments')
app.add_middleware(
    CORSMiddleware,
    allow_origins=s.origins,
    allow_origin_regex=(
        r'^https?://(?:localhost|127\.0\.0\.1)(?::\d+)?$'
        if s.app_env == 'development' else None
    ),
    allow_credentials=False,
    allow_methods=['*'],
    allow_headers=['*'],
)
app.include_router(router,prefix='/api/v1')
@app.get('/')
def root():return {'name':'MEMORA API','docs':'/docs','health':'/health'}
@app.get('/health')
def health():return {'status':'ok','service':'memora-api','environment':s.app_env}
