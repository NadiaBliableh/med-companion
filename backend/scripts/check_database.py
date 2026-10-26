import psycopg

from app.database import get_connection


def main():
    try:
        with get_connection() as connection:
            result = connection.execute(
                """
                SELECT
                    current_database() AS database_name,
                    to_regclass('public.users')::text AS users_table,
                    to_regclass('public.student_profiles')::text
                        AS student_profiles_table;
                """
            ).fetchone()

        print("Database connection successful.")
        print("Database:", result["database_name"])
        print("Users table:", result["users_table"])
        print("Student profiles table:", result["student_profiles_table"])

        if (
            result["users_table"] is None
            or result["student_profiles_table"] is None
        ):
            print("WARNING: One or more required tables are missing.")

    except psycopg.Error:
        print(
            "Database connection failed. "
            "Check PostgreSQL is running and verify your .env settings."
        )
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()