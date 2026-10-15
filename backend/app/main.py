from datetime import date, timedelta

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .models import Assignment
from .schemas import AssignmentCreate, AssignmentOut, AssignmentUpdate, StatsOut

app = FastAPI(title=settings.app_name, version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
Instrumentator().instrument(app).expose(app, endpoint="/metrics")


@app.get("/")
def root():
    return {"service": settings.app_name, "version": "1.0.0", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "UP"}


@app.get("/ready")
def ready(db: Session = Depends(get_db)):
    db.execute(select(func.count(Assignment.id)))
    return {"status": "READY"}


@app.get("/api/assignments", response_model=list[AssignmentOut])
def list_assignments(db: Session = Depends(get_db)):
    return list(
        db.scalars(
            select(Assignment).order_by(
                Assignment.due_date.is_(None), Assignment.due_date, Assignment.id.desc()
            )
        )
    )


@app.get("/api/assignments/stats", response_model=StatsOut)
def assignment_stats(db: Session = Depends(get_db)):
    rows = db.execute(
        select(Assignment.status, func.count(Assignment.id)).group_by(Assignment.status)
    ).all()
    counts = {assignment_status: count for assignment_status, count in rows}
    today = date.today()
    due_soon = db.scalar(
        select(func.count(Assignment.id)).where(
            Assignment.status != "DONE",
            Assignment.due_date >= today,
            Assignment.due_date <= today + timedelta(days=7),
        )
    ) or 0
    return StatsOut(
        total=sum(counts.values()),
        todo=counts.get("TODO", 0),
        inProgress=counts.get("IN_PROGRESS", 0),
        done=counts.get("DONE", 0),
        dueSoon=due_soon,
    )


@app.get("/api/assignments/{assignment_id}", response_model=AssignmentOut)
def get_assignment(assignment_id: int, db: Session = Depends(get_db)):
    assignment = db.get(Assignment, assignment_id)
    if assignment is None:
        raise HTTPException(status_code=404, detail="Assignment not found")
    return assignment


@app.post(
    "/api/assignments",
    response_model=AssignmentOut,
    status_code=status.HTTP_201_CREATED,
)
def create_assignment(payload: AssignmentCreate, db: Session = Depends(get_db)):
    assignment = Assignment(**payload.model_dump())
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    return assignment


@app.put("/api/assignments/{assignment_id}", response_model=AssignmentOut)
def update_assignment(
    assignment_id: int, payload: AssignmentUpdate, db: Session = Depends(get_db)
):
    assignment = db.get(Assignment, assignment_id)
    if assignment is None:
        raise HTTPException(status_code=404, detail="Assignment not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(assignment, key, value)
    db.commit()
    db.refresh(assignment)
    return assignment


@app.delete("/api/assignments/{assignment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_assignment(assignment_id: int, db: Session = Depends(get_db)):
    assignment = db.get(Assignment, assignment_id)
    if assignment is None:
        raise HTTPException(status_code=404, detail="Assignment not found")
    db.delete(assignment)
    db.commit()
