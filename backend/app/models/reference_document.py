import uuid

from sqlalchemy import Date, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class ReferenceDocument(Base):
    __tablename__ = "reference_documents"
    __table_args__ = (
        UniqueConstraint("reference_name", "reference_version", name="uq_reference_documents_name_version"),
    )

    reference_document_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reference_name: Mapped[str] = mapped_column(String, nullable=False)
    notice_number: Mapped[str | None] = mapped_column(String, nullable=True)
    reference_version: Mapped[str] = mapped_column(String, nullable=False)
    effective_date: Mapped[Date | None] = mapped_column(Date, nullable=True)
    source_document: Mapped[str] = mapped_column(Text, nullable=False)
