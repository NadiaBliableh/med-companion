from getpass import getpass

import psycopg
from email_validator import validate_email, EmailNotValidError

from database import get_connection
from security import hash_password


def main():
    full_name = input("Full name: ").strip()
    email_input = input("Email: ").strip()

    if not full_name or len(full_name) > 150:
        print("Name must contain between 1 and 150 characters.")
        return

    try:
        email = validate_email(
            email_input,
            check_deliverability=False,
        ).normalized.lower()
    except EmailNotValidError:
        print("Invalid email format.")
        return

    if len(email) > 254:
        print("Email is too long.")
        return

    password = getpass("Password (15-128 characters): ")
    confirmation = getpass("Confirm password: ")

    if not 15 <= len(password) <= 128:
        print("Password must contain between 15 and 128 characters.")
        return

    if password != confirmation:
        print("Passwords do not match.")
        return

    password_hash = hash_password(password)

    try:
        with get_connection() as connection:
            existing_user = connection.execute(
                """
                SELECT id
                FROM public.users
                WHERE LOWER(TRIM(email)) = %s;
                """,
                (email,),
            ).fetchone()

            if existing_user:
                print("This email already exists. No changes were made.")
                return

            user = connection.execute(
                """
                INSERT INTO public.users (
                    full_name,
                    email,
                    password_hash,
                    role
                )
                VALUES (%s, %s, %s, 'student')
                RETURNING id, full_name, email;
                """,
                (full_name, email, password_hash),
            ).fetchone()

            connection.execute(
                """
                INSERT INTO public.student_profiles (
                    user_id,
                    preferred_language
                )
                VALUES (%s, 'ar');
                """,
                (user["id"],),
            )

        # نطبع النجاح بعد حفظ المعاملة
        print("\nTest student created successfully.")
        print("User ID:", user["id"])
        print("Name:", user["full_name"])
        print("Email:", user["email"])

    except psycopg.errors.UniqueViolation:
        print("A record with these unique details already exists.")

    except psycopg.Error:
        print(
            "Could not create the student. "
            "Check the database connection and table definitions."
        )


if __name__ == "__main__":
    main()