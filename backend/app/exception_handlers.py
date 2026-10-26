import psycopg
from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


async def validation_error_handler(request, exc):
    # لا نعيد قيم المدخلات، خصوصًا كلمة المرور، داخل رسائل الخطأ
    errors = [
        {
            "loc": error["loc"],
            "msg": error["msg"],
            "type": error["type"],
        }
        for error in exc.errors()
    ]
    return JSONResponse(status_code=422, content={"detail": errors})


async def database_error_handler(request, exc):
    return JSONResponse(
        status_code=503,
        content={"detail": "Database service is temporarily unavailable."},
    )


def register_exception_handlers(app: FastAPI):
    app.add_exception_handler(
        RequestValidationError,
        validation_error_handler,
    )
    app.add_exception_handler(
        psycopg.Error,
        database_error_handler,
    )
