from datetime import date
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StrictInt,
    field_validator,
    model_validator,
)


class StudentProfileResponse(BaseModel):
    id: int
    full_name: str
    email: str
    university: str | None
    study_year: int | None
    preferred_language: Literal["ar", "en"]


class StudentProfileUpdate(BaseModel):
    # نرفض أي حقل غير مسموح (id, user_id, email, role, password, progress, ...)
    model_config = ConfigDict(extra="forbid")

    # القيمة الافتراضية None تجعل الحقل اختياريًا للتحديث الجزئي.
    # لا تُشغَّل دوال التحقق على هذه القيمة الافتراضية إلا إذا أُرسل الحقل فعلًا،
    # لذلك "الحقل غير المرسل" يبقى كما هو، بينما "null" المُرسَل يصل إلى التحقق.
    full_name: str | None = None
    university: str | None = None
    study_year: StrictInt | None = Field(default=None, ge=1, le=6)
    preferred_language: Literal["ar", "en"] | None = None

    @field_validator("full_name")
    @classmethod
    def clean_full_name(cls, value):
        if value is None:
            raise ValueError("full_name cannot be null.")
        value = value.strip()
        if not 1 <= len(value) <= 150:
            raise ValueError(
                "full_name must be between 1 and 150 characters."
            )
        return value

    @field_validator("university")
    @classmethod
    def clean_university(cls, value):
        # null أو نص فارغ يعني مسح الجامعة.
        if value is None:
            return None
        value = value.strip()
        if value == "":
            return None
        if len(value) > 200:
            raise ValueError("university must be at most 200 characters.")
        return value

    @field_validator("preferred_language")
    @classmethod
    def check_preferred_language(cls, value):
        if value is None:
            raise ValueError("preferred_language cannot be null.")
        return value

    @model_validator(mode="after")
    def require_at_least_one_field(self):
        # الطلب الفارغ {} غير مقبول.
        if not self.model_fields_set:
            raise ValueError(
                "At least one field must be provided to update."
            )
        return self


# ---------------------------------------------------------------------------
# نماذج استجابة شاشة البروفايل (GET /students/me/profile-overview).
# كلها للقراءة فقط؛ القيم تُحسب لحظيًا في الـservice ولا تُخزَّن.
# ---------------------------------------------------------------------------


class OverviewProfile(BaseModel):
    full_name: str
    avatar_url: str | None  # غير مخزَّن؛ تولّد الواجهة الأحرف الأولى من الاسم.
    study_year: int | None
    preferred_language: Literal["ar", "en"]


class OverviewStats(BaseModel):
    current_streak_days: int
    total_study_seconds: int
    overall_progress_percentage: float


class ContinueLearning(BaseModel):
    subject_id: int
    subject_title: str
    topic_id: int
    topic_title: str
    lesson_id: int
    lesson_title: str
    lesson_order: int
    # عدد الدروس المنشورة والمتاحة في نفس الـtopic (مقام تقدّم الـtopic).
    lessons_count: int
    # حالة الدرس وفق lesson_progress: not_started (لا صف) أو in_progress.
    # درس المتابعة لا يكون completed أبدًا (الاختيار يستبعد المكتمل).
    # لا يوجد استئناف من موضع داخل محتوى الدرس (لا تتبّع على مستوى blocks).
    status: Literal["not_started", "in_progress"]
    # تقدّم على مستوى الـtopic: دروس منشورة أكملها الطالب في هذا الـtopic.
    completed_lessons_in_topic: int
    # completed_lessons_in_topic / lessons_count × 100 (مقرّبة).
    topic_progress_percentage: float
    thumbnail_url: str | None  # غير مخزَّن في lessons؛ يبقى null حاليًا.


class WeeklyActivityItem(BaseModel):
    date: date
    study_seconds: int


class ProfileOverviewResponse(BaseModel):
    profile: OverviewProfile
    stats: OverviewStats
    continue_learning: ContinueLearning | None
    weekly_activity: list[WeeklyActivityItem]
    saved_lessons_count: int
