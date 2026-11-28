"""Generación acotada en tiempo con respaldo determinístico."""

import asyncio
import re
import unicodedata

from ..core.report_config import REPORT_MAX_WORDS, REPORT_TIMEOUT_SECONDS
from .reports import (
    DISCLAIMER, LEVEL_LABELS, TREND_SIGNALS, ReportInput, ReportResult, ReportWriter,
    local_report, render_facts,
)

_UNSUITABLE_LANGUAGE = re.compile(
    r"deterior|demenci|alzheimer|diagnostic|patologic|anormal|enfermedad|"
    r"\b(?:cura|curar|previene|revertir|urgente|alarmante)\b"
)


def validated_text(text: str, report: ReportInput) -> str | None:
    """El aviso lo añade el servidor: no se delega su presencia al modelo."""
    if not isinstance(text, str):
        return None
    body = text.strip()
    if body.endswith(DISCLAIMER):
        body = body[:-len(DISCLAIMER)].strip()
    normalized = "".join(
        char for char in unicodedata.normalize("NFKD", body.casefold())
        if not unicodedata.combining(char)
    )
    # Se pide una síntesis sin cifras para no introducir números inventados.
    if (not body or _UNSUITABLE_LANGUAGE.search(normalized)
            or re.search(r"\d|https?://|@", normalized)):
        return None
    for summary in report.summaries:
        labels = ("motricidad", "praxias") if summary.domain == "praxias" else (summary.domain,)
        if not any(re.search(rf"\b{label}\b", normalized) for label in labels):
            return None
        if summary.level is not None and not re.search(
            rf"\b{LEVEL_LABELS[summary.level]}\b", normalized,
        ):
            return None
    result = f"{body}\n\n{DISCLAIMER}"
    if len(result.split()) > REPORT_MAX_WORDS:
        return None
    return result


async def generate_report(report: ReportInput, writer: ReportWriter) -> ReportResult:
    if not any(summary.sessions for summary in report.summaries):
        return local_report(report, "no_data")
    # No se solicita interpretación a IA cuando no hay ninguna tendencia calculada.
    if not any(summary.signal in TREND_SIGNALS for summary in report.summaries):
        reason = "calibration_pending" if any(
            summary.signal == "calibracion_pendiente" for summary in report.summaries
        ) else "insufficient_data"
        return local_report(report, reason)
    try:
        # El plazo cubre la llamada completa, no cada lectura de red por separado.
        async with asyncio.timeout(REPORT_TIMEOUT_SECONDS):
            text = await writer.write(render_facts(report))
    except TimeoutError:
        return local_report(report, "timeout")
    except Exception:
        # No se devuelven ni registran mensajes del proveedor o cuerpos de requests.
        return local_report(report, "service_error")
    text = validated_text(text, report)
    if text is None:
        return local_report(report, "invalid_response")
    return ReportResult(text=text, source="openai")
