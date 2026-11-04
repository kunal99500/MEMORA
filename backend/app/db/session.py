from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from app.core.config import get_settings
s=get_settings(); args={'check_same_thread':False} if s.database_url.startswith('sqlite') else {}
if s.database_url.startswith('sqlite'):
    args['timeout'] = 30
engine=create_engine(s.database_url,connect_args=args,pool_pre_ping=True)
if s.database_url.startswith('sqlite'):
    @event.listens_for(engine, 'connect')
    def _configure_sqlite_connection(connection, _record):
        del _record
        cursor=connection.cursor()
        try:
            cursor.execute('PRAGMA busy_timeout=30000')
            cursor.execute('PRAGMA journal_mode=WAL')
        finally:
            cursor.close()
SessionLocal=sessionmaker(bind=engine,autoflush=False,autocommit=False)
def get_db():
    db=SessionLocal()
    try: yield db
    finally: db.close()
