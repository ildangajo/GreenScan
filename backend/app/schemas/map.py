from pydantic import BaseModel


class GeocodeResponse(BaseModel):
    region_id: str
    hdd_lookup_key: str
    latitude: float
    longitude: float
    road_address: str | None = None
