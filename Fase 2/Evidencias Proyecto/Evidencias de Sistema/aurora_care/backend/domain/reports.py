"""Hechos y plantillas del reporte; no calcula scoring ni estados de salud."""

from dataclasses import dataclass
from typing import Literal, Protocol

Domain = Literal["memoria", "atencion", "praxias"]
Signal = Literal[
    "estable", "mejora", "atencion", "revisar", "insuficiente", "calibracion_pendiente"
]
FallbackReason = Literal[
    "timeout", "service_error", "invalid_response", "no_data",
    "insufficient_data", "calibration_pending",
]

DISCLAIMER = (
    "Este reporte no constituye un diagnóstico médico. "
    "Consulte a un profesional de la salud para una evaluación completa."
)
DOMAIN_LABELS = {"memoria": "Memoria", "atencion": "Atención", "praxias": "Motricidad (praxias)"}
LEVEL_LABELS = {1: "inicial", 2: "intermedio", 3: "avanzado"}
TREND_SIGNALS = {"estable", "mejora", "atencion", "revisar"}
SIGNAL_TEXT = {
    "estable": "El desempeño en estos ejercicios se mantiene consistente.",
    "mejora": "El desempeño en estos ejercicios muestra una tendencia favorable.",
    "atencion": "Se observan variaciones; puede seguir practicando a su ritmo.",
    "revisar": "Se observan variaciones sostenidas; puede comentarlas con un profesional de salud.",
    "insuficiente": "Aún faltan sesiones comparables para describir una tendencia.",
    "calibracion_pendiente": "La práctica está registrada; la puntuación y la tendencia esperan calibración.",
}


@dataclass(frozen=True)
class DomainSummary:
    domain: Domain
    sessions: int
    signal: Signal
    level: int | None = None
    average_score: float | None = None


@dataclass(frozen=True)
class ReportInput:
    period_days: int
    summaries: tuple[DomainSummary, ...]


@dataclass(frozen=True)
class ReportResult:
    text: str
    source: Literal["openai", "plantilla_local"]
    fallback_reason: FallbackReason | None = None


class ReportWriter(Protocol):
    async def write(self, facts: str) -> str: ...


def render_facts(report: ReportInput) -> str:
    """Solo campos validados y etiquetas fijas; nunca texto libre del cliente."""
    paragraphs = [f"Resumen de los últimos {report.period_days} días."]
    for summary in report.summaries:
        label = DOMAIN_LABELS[summary.domain]
        if summary.sessions == 0:
            paragraphs.append(f"{label}: no hay sesiones registradas en este período.")
            continue
        details = f"{summary.sessions} sesiones"
        if summary.level is not None:
            details += f" de nivel {LEVEL_LABELS[summary.level]}"
        if summary.average_score is not None:
            score = f"{summary.average_score:.1f}".replace(".", ",")
            details += f", puntuación media {score}/100"
        paragraphs.append(f"{label}: {details}. {SIGNAL_TEXT[summary.signal]}")
    paragraphs.append("Las puntuaciones son orientativas de los ejercicios, sin interpretación clínica.")
    return "\n\n".join(paragraphs)


def local_report(report: ReportInput, reason: FallbackReason) -> ReportResult:
    return ReportResult(
        text=f"{render_facts(report)}\n\n{DISCLAIMER}",
        source="plantilla_local",
        fallback_reason=reason,
    )
