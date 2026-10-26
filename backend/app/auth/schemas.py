from datetime import datetime
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
)

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserResponse(BaseModel):
    id: int
    full_name: str
    email: str
    role: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: UserResponse


class SignupRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(min_length=1, max_length=150)
    email: EmailStr = Field(max_length=254)
    password: str = Field(min_length=15, max_length=128)
    university: str | None = Field(default=None, max_length=200)
    study_year: int | None = Field(default=None, ge=1, le=6)
    preferred_language: Literal["ar", "en"] = "ar"

    @field_validator("full_name", mode="before")
    @classmethod
    def clean_full_name(cls, value):
        if isinstance(value, str):
            return value.strip()
        return value

    @field_validator("university", mode="before")
    @classmethod
    def clean_university(cls, value):
        if isinstance(value, str):
            return value.strip() or None
        return value
