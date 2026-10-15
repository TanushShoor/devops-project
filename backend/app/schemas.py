from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Status = Literal["TODO", "IN_PROGRESS", "DONE"]
Priority = Literal["LOW", "MEDIUM", "HIGH"]


class AssignmentCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=2000)
    course: str = Field(min_length=1, max_length=120)
    due_date: date | None = None
    priority: Priority = "MEDIUM"
    status: Status = "TODO"


class AssignmentUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    course: str | None = Field(default=None, min_length=1, max_length=120)
    due_date: date | None = None
    priority: Priority | None = None
    status: Status | None = None


class AssignmentOut(AssignmentCreate):
    id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class StatsOut(BaseModel):
    total: int
    todo: int
    inProgress: int
    done: int
    dueSoon: int
