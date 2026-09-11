from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class FavoriteCreateRequest(BaseModel):
    diagnosis_id: UUID


class FavoriteItem(BaseModel):
    favorite_id: UUID
    diagnosis_id: UUID
    created_at: datetime

    model_config = {"from_attributes": True}


class FavoriteListResponse(BaseModel):
    favorites: list[FavoriteItem]
