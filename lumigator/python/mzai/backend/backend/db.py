import contextlib
from collections.abc import Generator

import sqlite3

from sqlalchemy import Connection, Engine, create_engine, event
from sqlalchemy.orm import Session, sessionmaker
from sqlite3 import Connection as SQLite3Connection

from backend.settings import settings


class DatabaseSessionManager:
    """Connection/session manager for SQLAlchemy database engines.

    Connections and sessions are obtained by the `connect` and `session` methods,
    which establish SQL transactions and handles rollbacks in case of exceptions.
    """

    def __init__(self, engine: Engine):
        self._engine = engine
        self._sessionmaker = sessionmaker(autocommit=False, autoflush=False, bind=self._engine)

    @contextlib.contextmanager
    def connect(self) -> Generator[Connection, None, None]:
        """Yield a transactional connection, rolling back on errors."""
        with self._engine.begin() as connection:
            try:
                yield connection
            except Exception:
                connection.rollback()
                raise

    @contextlib.contextmanager
    def session(self) -> Generator[Session, None, None]:
        """Yield a transactional session, rolling back on errors."""
        session = self._sessionmaker()
        try:
            yield session
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()


@event.listens_for(Engine, "connect")
def _set_sqlite_pragma(dbapi_connection, connection_record):
    if isinstance(dbapi_connection, SQLite3Connection):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON;")
        cursor.close()


# TODO: Override echo param with WARN at the app logging level
engine = create_engine(settings.SQLALCHEMY_DATABASE_URL, echo=False)
session_manager = DatabaseSessionManager(engine)
