from fastapi import APIRouter, Depends, HTTPException, Response

from app.dependencies import get_current_session
from app.students.schemas import StudentProfileResponse, StudentProfileUpdate
from app.students.service import get_student_profile, update_student_profile


router = APIRouter(prefix="/students")


def get_student_session(session=Depends(get_current_session)):
    # user_id يُؤخذ من الجلسة فقط، ولا يُقبل من المستخدم.
    if session["role"] != "student":
        raise HTTPException(
            status_code=403,
            detail="Only students can access the student profile.",
        )
    return session


@router.get("/me", response_model=StudentProfileResponse)
def read_my_profile(
    response: Response,
    session=Depends(get_student_session),
):
    profile = get_student_profile(session["id"])
    response.headers["Cache-Control"] = "no-store"
    return profile


@router.patch("/me", response_model=StudentProfileResponse)
def update_my_profile(
    body: StudentProfileUpdate,
    response: Response,
    session=Depends(get_student_session),
):
    changes = body.model_dump(exclude_unset=True)
    profile = update_student_profile(session["id"], changes)
    response.headers["Cache-Control"] = "no-store"
    return profile
