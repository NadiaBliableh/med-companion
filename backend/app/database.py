import psycopg
from psycopg.rows import dict_row

from app.config import settings


def get_connection():
    return psycopg.connect(
        host=settings.db_host,
        port=settings.db_port,
        dbname=settings.db_name,
        user=settings.db_user,
        password=settings.db_password.get_secret_value(),
        connect_timeout=5,
        row_factory=dict_row,
    )