from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI

from app.auth.router import router as auth_router
from app.exception_handlers import register_exception_handlers
from app.learning.router import router as learning_router
from app.students.router import router as students_router


app = FastAPI(
    title="Med Companion API",
    version="0.1.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_methods=["GET", "POST", "PATCH"],
    allow_headers=["Content-Type", "Authorization"],
)

register_exception_handlers(app)


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(auth_router)
app.include_router(students_router)
app.include_router(learning_router)
