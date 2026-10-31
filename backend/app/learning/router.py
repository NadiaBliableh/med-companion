from fastapi import APIRouter, Depends, Response

from app.learning.schemas import SubjectListResponse, SubjectOutlineResponse
from app.learning.service import get_subject_outline, list_published_subjects
from app.students.router import get_student_session


router = APIRouter(prefix="/learning")


@router.get("/subjects", response_model=SubjectListResponse)
def read_subjects(
    response: Response,
    session=Depends(get_student_session),
):
    subjects = list_published_subjects()
    response.headers["Cache-Control"] = "no-store"
    return {"subjects": subjects}


@router.get(
    "/subjects/{subject_id}/outline",
    response_model=SubjectOutlineResponse,
    responses={404: {"description": "Published subject not found"}},
)
def read_subject_outline(
    subject_id: int,
    response: Response,
    session=Depends(get_student_session),
):
    outline = get_subject_outline(subject_id, session["id"])
    response.headers["Cache-Control"] = "no-store"
    return outline
