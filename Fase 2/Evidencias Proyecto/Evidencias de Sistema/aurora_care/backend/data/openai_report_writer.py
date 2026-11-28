"""Adaptador OpenAI: solo recibe hechos agregados, sin contexto del request HTTP."""

import os

from openai import APITimeoutError, AsyncOpenAI

from ..core.report_config import DEFAULT_REPORT_MODEL, REPORT_TIMEOUT_SECONDS

SYSTEM_PROMPT = (
    "Redacta en español una síntesis de bienestar para una persona mayor, su cuidador "
    "y un profesional de salud. Usa lenguaje sencillo, respetuoso y cuidadoso. "
    "Describe únicamente los hechos suministrados, sin calcular puntuaciones ni tendencias. "
    "Distingue cada dominio y su nivel cuando esté disponible. No generalices una señal "
    "a otros dominios. Si faltan sesiones o calibración, dilo sin inferir una tendencia. "
    "No infieras estados de salud ni relaciones de causa y efecto. "
    "No uses deterioro, demencia, Alzheimer, diagnóstico, patológico, anormal o enfermedad. "
    "No prometas prevención, curación ni recuperación. No añadas nombres, identificadores, "
    "fechas, cifras, enlaces, tratamientos ni recomendaciones de frecuencia. "
    "No conviertas niveles de juego en grados de salud. "
    "Entrega solo texto, con un máximo de ciento veinte palabras. "
    "No añadas un aviso médico: el servidor lo incorporará después."
)


class OpenAIReportWriter:
    async def write(self, facts: str) -> str:
        try:
            return await self._write(facts)
        except APITimeoutError:
            raise TimeoutError from None

    async def _write(self, facts: str) -> str:
        # Sin reintentos automáticos: nunca prolongar el plazo de ocho segundos.
        async with AsyncOpenAI(
            api_key=os.getenv("OPENAI_API_KEY"),
            timeout=REPORT_TIMEOUT_SECONDS,
            max_retries=0,
        ) as client:
            response = await client.chat.completions.create(
                model=os.getenv("OPENAI_REPORT_MODEL", DEFAULT_REPORT_MODEL),
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": facts},
                ],
                max_completion_tokens=500,
                store=False,
            )
        if not response.choices or response.choices[0].finish_reason != "stop":
            return ""
        message = response.choices[0].message
        if message.refusal:
            return ""
        return message.content or ""
