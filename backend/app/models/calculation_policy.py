import uuid

from sqlalchemy import ForeignKey, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class CalculationPolicy(Base):
    __tablename__ = "calculation_policies"

    calculation_policy_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    formula_version: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    result_message_policy_version: Mapped[str] = mapped_column(String, nullable=False)


class CalculationScenario(Base):
    __tablename__ = "calculation_scenarios"
    __table_args__ = (
        UniqueConstraint("calculation_policy_id", "scenario_key", name="uq_calculation_scenarios_policy_key"),
    )

    calculation_scenario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    calculation_policy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("calculation_policies.calculation_policy_id"), nullable=False
    )
    scenario_key: Mapped[str] = mapped_column(String, nullable=False)
    display_name: Mapped[str] = mapped_column(String, nullable=False)


class CalculationScenarioComponent(Base):
    __tablename__ = "calculation_scenario_components"

    calculation_scenario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("calculation_scenarios.calculation_scenario_id"),
        primary_key=True,
    )
    component_key: Mapped[str] = mapped_column(
        String, ForeignKey("building_components.component_key"), primary_key=True
    )


class CalculationResultMessagePolicy(Base):
    __tablename__ = "calculation_result_message_policies"
    __table_args__ = (
        UniqueConstraint(
            "calculation_policy_id", "message_key", name="uq_calculation_result_message_policies_policy_key"
        ),
    )

    calculation_result_message_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    calculation_policy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("calculation_policies.calculation_policy_id"), nullable=False
    )
    message_key: Mapped[str] = mapped_column(String, nullable=False)
    message_text: Mapped[str] = mapped_column(Text, nullable=False)
