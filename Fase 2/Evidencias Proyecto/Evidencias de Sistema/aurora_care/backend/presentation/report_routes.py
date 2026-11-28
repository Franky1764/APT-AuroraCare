"""Contrato de HU-38: lista cerrada de campos, categorías y rangos."""

from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Request, Response
from fastapi.exception_handlers import request_validation_exception_handler
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, model_validator

from ..domain.generate_report import generate_report
from ..domain.reports import (
    TREND_SIGNALS, Domain, DomainSummary, FallbackReason, ReportInput,
    ReportWriter, Signal,
)


class ValidatedReportData(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, allow_inf_nan=False)


class ReportDomainSummary(ValidatedReportData):
    sessions: int = Field(alias="sesiones", ge=0, le=10000)
    signal: Signal = Field(alias="senal")
    level: int | None = Field(default=None, alias="nivel_senal", ge=1, le=3)
    average_score: float | None = Field(default=None, alias="score_promedio", ge=0, le=100)

    @model_validator(mode="after")
    def validate_consistency(self):
        if self.average_score is not None and (self.sessions == 0 or self.level is None):
            raise ValueError("Una puntuación requiere sesiones y nivel")
        if self.signal in TREND_SIGNALS and (
            self.sessions < 5 or self.level is None or self.average_score is None
        ):
            raise ValueError("Una tendencia requiere al menos cinco sesiones puntuadas del mismo nivel")
        if self.signal == "calibracion_pendiente" and self.average_score is not None:
            raise ValueError("Sin calibración no hay puntuación")
        if self.signal == "insuficiente" and self.sessions >= 5 and self.average_score is not None:
            raise ValueError("Las sesiones puntuadas suficientes requieren su señal calculada")
        return self


class ReportGenerateRequest(ValidatedReportData):
    period_days: int = Field(default=28, alias="periodo_dias", ge=1, le=28)
    summaries: dict[Domain, ReportDomainSummary] = Field(
        alias="resumen_dominios", min_length=1, max_length=3,
    )

    def to_domain(self) -> ReportInput:
        return ReportInput(
            period_days=self.period_days,
            summaries=tuple(
                DomainSummary(domain=domain, **self.summaries[domain].model_dump())
                for domain in ("memoria", "atencion", "praxias") if domain in self.summaries
            ),
        )


class ReportGenerateResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    text: str = Field(alias="reporte_texto")
    source: Literal["openai", "plantilla_local"] = Field(alias="generado_con")
    fallback_reason: FallbackReason | None = Field(default=None, alias="motivo_respaldo")


class InvalidReportDetail(BaseModel):
    code: Literal["invalid_report_data"]
    message: str


class InvalidReportResponse(BaseModel):
    detail: InvalidReportDetail


def get_report_writer() -> ReportWriter:
    raise NotImplementedError("El punto de entrada debe inyectar ReportWriter")


router = APIRouter()


async def report_validation_error_handler(request: Request, exc: RequestValidationError):
    if request.url.path == "/report/generate":
        # No reflejar datos personales rechazados ni valores NaN en el error.
        return JSONResponse(
            status_code=422,
            content={"detail": {
                "code": "invalid_report_data",
                "message": "Envíe solo los dominios, cantidades, niveles y señales permitidos.",
            }},
            headers={"Cache-Control": "no-store"},
        )
    return await request_validation_exception_handler(request, exc)


@router.post(
    "/report/generate", response_model=ReportGenerateResponse,
    responses={422: {"model": InvalidReportResponse}},
)
async def report_generate(
    data: ReportGenerateRequest,
    response: Response,
    writer: Annotated[ReportWriter, Depends(get_report_writer)],
) -> ReportGenerateResponse:
    response.headers["Cache-Control"] = "no-store"
    result = await generate_report(data.to_domain(), writer)
    return ReportGenerateResponse(
        text=result.text,
        source=result.source,
        fallback_reason=result.fallback_reason,
    )
