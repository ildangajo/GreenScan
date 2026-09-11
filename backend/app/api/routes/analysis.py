import io

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError

from app.core.config import settings
from app.schemas.common import ErrorResponse
from app.schemas.vision import PhotoAnalysisResponse, PhotoCategory
from app.services.vision_service import analyze_photo

router = APIRouter(prefix="/photos", tags=["photos"])

_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
# api-spec.md 2.3 정책 확정: 사진 1장 최대 10MB.
_MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024


@router.post(
    "/analyze",
    response_model=PhotoAnalysisResponse,
    responses={400: {"model": ErrorResponse}},
)
async def analyze_photo_endpoint(
    category: str = Form(...),
    image: UploadFile = File(...),
) -> PhotoAnalysisResponse:
    try:
        category_enum = PhotoCategory(category)
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "PHOTO_CATEGORY_INVALID", "message": "category는 window 또는 wall이어야 합니다."},
        ) from exc

    if image.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "PHOTO_INVALID_FORMAT", "message": "지원하지 않는 파일 형식입니다."},
        )

    image_bytes = await image.read()

    if len(image_bytes) > _MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "PHOTO_TOO_LARGE",
                "message": "파일 용량은 10MB를 초과할 수 없습니다.",
                "detail": {"max_size_bytes": _MAX_FILE_SIZE_BYTES},
            },
        )

    try:
        with Image.open(io.BytesIO(image_bytes)) as img:
            img.verify()
    except UnidentifiedImageError as exc:
        raise HTTPException(
            status_code=400,
            detail={"error_code": "PHOTO_CORRUPTED", "message": "이미지 파일이 손상되었습니다."},
        ) from exc

    result = analyze_photo(category=category_enum, image_bytes=image_bytes, content_type=image.content_type)
    # image_bytes는 함수 스코프를 벗어나면 폐기된다. 어디에도 저장하지 않는다.

    return PhotoAnalysisResponse(**result.model_dump(), model_version=settings.vision_model)
