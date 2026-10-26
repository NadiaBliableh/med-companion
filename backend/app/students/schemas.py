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
