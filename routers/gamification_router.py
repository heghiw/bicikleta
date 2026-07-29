from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from auth import get_current_user
import models
import schemas

router = APIRouter(prefix="/gamification", tags=["gamification"])


@router.get("/leaderboard", response_model=List[schemas.LeaderboardEntry])
def leaderboard(
    limit: int = 20,
    db: Session = Depends(get_db),
    _: models.User = Depends(get_current_user),
):
    """Top users by XP this month."""
    rows = (
        db.query(models.UserGamification, models.User)
        .join(models.User, models.UserGamification.user_id == models.User.id)
        .order_by(models.UserGamification.xp.desc())
        .limit(limit)
        .all()
    )
    return [
        schemas.LeaderboardEntry(
            rank=idx + 1,
            user_id=user.id,
            name=user.name,
            xp=g.xp,
            level=g.level,
            total_deliveries=g.total_deliveries,
        )
        for idx, (g, user) in enumerate(rows)
    ]
