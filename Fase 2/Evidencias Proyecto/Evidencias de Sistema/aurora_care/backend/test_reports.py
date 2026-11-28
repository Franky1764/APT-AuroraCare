"""HU-38: pruebas sin red ni credenciales reales, con Python 3.11+."""

import asyncio
import itertools
import json
import time
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx
from fastapi.testclient import TestClient
from openai import APITimeoutError, AsyncOpenAI

from backend.core.report_config import REPORT_MAX_WORDS, REPORT_TIMEOUT_SECONDS
from backend.data.openai_report_writer import OpenAIReportWriter
from backend.domain.generate_report import generate_report
from backend.domain.reports import (
    DISCLAIMER, SIGNAL_TEXT, DomainSummary, ReportInput, local_report,
)
from backend.main import app
from backend.presentation.report_routes import ReportGenerateRequest, get_report_writer

SUCCESS_TEXT = (
    "Memoria: el desempeño en el nivel intermedio se mantiene consistente. "
    "Estas observaciones describen los ejercicios practicados y no evalúan "
    "el estado de salud. Puede continuar practicando a su ritmo."
)


def payload():
    return {
        "periodo_dias": 28,
        "resumen_dominios": {
            "memoria": {"nivel_senal": 2, "score_promedio": 68.2,
                        "senal": "estable", "sesiones": 8},
        },
    }


class ReportEndpointTests(unittest.TestCase):
    def setUp(self):
        self.old_overrides = app.dependency_overrides.copy()
        self.writer = SimpleNamespace(write=AsyncMock(return_value=SUCCESS_TEXT))
        app.dependency_overrides[get_report_writer] = lambda: self.writer
        self.client = TestClient(app)
        self.addCleanup(self.client.close)
        self.addCleanup(self.restore_overrides)

    def restore_overrides(self):
        app.dependency_overrides.clear()
        app.dependency_overrides.update(self.old_overrides)

    def post(self, data=None):
        return self.client.post("/report/generate", json=payload() if data is None else data)

    def test_success_contract_and_mandatory_disclaimer(self):
        response = self.post()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["cache-control"], "no-store")
        self.assertEqual(response.json(), {
            "reporte_texto": SUCCESS_TEXT + "\n\n" + DISCLAIMER,
            "generado_con": "openai", "motivo_respaldo": None,
        })
        facts = self.writer.write.call_args.args[0]
        self.assertIn("8 sesiones de nivel intermedio", facts)
        self.assertIn("68,2/100", facts)

    def test_rejects_identifiers_at_every_supported_level_before_openai(self):
        for key in ("name", "nombre", "email", "uid", "uuid", "session_uuid",
                    "adultUUID", "fecha_nacimiento", "historial", "observaciones"):
            for location in ("root", "summary", "domain_key"):
                data = payload()
                if location == "root":
                    data[key] = "persona@example.test"
                elif location == "summary":
                    data["resumen_dominios"]["memoria"][key] = "persona@example.test"
                else:
                    data["resumen_dominios"][key] = data["resumen_dominios"].pop("memoria")
                with self.subTest(key=key, location=location):
                    response = self.post(data)
                    self.assertEqual(response.status_code, 422)
                    self.assertNotIn("persona@example.test", response.text)
        self.writer.write.assert_not_called()

    def test_rejects_free_text_coercions_invalid_numbers_and_inconsistent_signals(self):
        mutations = [
            ("periodo_dias", 0), ("periodo_dias", 29), ("periodo_dias", True),
            ("periodo_dias", "28"), ("resumen_dominios", {}),
            ("sesiones", -1), ("sesiones", 10001), ("sesiones", True),
            ("sesiones", "8"), ("sesiones", 4), ("nivel_senal", 0),
            ("nivel_senal", 4), ("nivel_senal", "Rosa"), ("nivel_senal", None),
            ("score_promedio", -1), ("score_promedio", 101),
            ("score_promedio", "68.2"), ("score_promedio", True),
            ("score_promedio", None), ("senal", "estable. Nombre: Rosa"),
            ("senal", "calibracion_pendiente"), ("senal", "insuficiente"),
        ]
        for field, value in mutations:
            data = payload()
            if field in ("periodo_dias", "resumen_dominios"):
                data[field] = value
            else:
                data["resumen_dominios"]["memoria"][field] = value
            with self.subTest(field=field, value=value):
                self.assertEqual(self.post(data).status_code, 422)
        for invalid in ("NaN", "Infinity", "-Infinity"):
            body = json.dumps(payload()).replace("68.2", invalid)
            self.assertEqual(self.client.post("/report/generate", content=body,
                             headers={"content-type": "application/json"}).status_code, 422)
        self.writer.write.assert_not_called()

    def test_service_failure_always_returns_complete_local_report(self):
        self.writer.write.side_effect = RuntimeError("provider-secret-or-request-id")
        result = self.post().json()
        self.assertEqual(result["generado_con"], "plantilla_local")
        self.assertEqual(result["motivo_respaldo"], "service_error")
        self.assertIn("68,2/100", result["reporte_texto"])
        self.assertTrue(result["reporte_texto"].endswith(DISCLAIMER))
        self.assertNotIn("provider-secret", json.dumps(result))

    def test_invalid_output_uses_template_including_length_and_language(self):
        outputs = ("", " ", None, "palabra " * 151, "Existe deterioro cognitivo.",
                   "Se confirma un DIAGNÓSTICO.", "El tratamiento cura la memoria.",
                   "Puntuación inventada: 99.", "Consulte https://example.test", "persona@test.cl", "Puede continuar practicando a su ritmo.",
                   "Memoria: el desempeño se mantiene consistente.")
        for output in outputs:
            self.writer.write.return_value = output
            with self.subTest(output=output):
                result = self.post().json()
                self.assertEqual(result["generado_con"], "plantilla_local")
                self.assertEqual(result["motivo_respaldo"], "invalid_response")

    def test_model_disclaimer_is_not_duplicated(self):
        self.writer.write.return_value = SUCCESS_TEXT + "\n" + DISCLAIMER
        self.assertEqual(self.post().json()["reporte_texto"].count(DISCLAIMER), 1)

    def test_initial_practice_and_pending_calibration_never_call_openai(self):
        for sessions, signal, reason in (
            (0, "insuficiente", "no_data"),
            (3, "insuficiente", "insufficient_data"),
            (12, "calibracion_pendiente", "calibration_pending"),
        ):
            data = {"resumen_dominios": {"praxias": {"sesiones": sessions, "senal": signal}}}
            with self.subTest(signal=signal, sessions=sessions):
                result = self.post(data).json()
                self.assertEqual(result["generado_con"], "plantilla_local")
                self.assertEqual(result["motivo_respaldo"], reason)
                self.assertIn("Motricidad (praxias)", result["reporte_texto"])
                self.assertNotIn("/100", result["reporte_texto"])
                self.assertNotIn("espere 28", result["reporte_texto"])
        self.writer.write.assert_not_called()

    def test_default_dependency_sends_no_caller_identity_or_headers_to_openai(self):
        captured = []

        def handler(request):
            captured.append(request)
            return httpx.Response(200, json={
                "id": "test-response", "object": "chat.completion", "created": 0,
                "model": "gpt-5.6-luna", "choices": [{"index": 0, "finish_reason": "stop",
                    "message": {"role": "assistant", "content": SUCCESS_TEXT}}],
            })

        def create_client(**kwargs):
            return AsyncOpenAI(api_key="test-provider-key", timeout=kwargs["timeout"],
                               max_retries=kwargs["max_retries"],
                               http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)))

        app.dependency_overrides[get_report_writer] = OpenAIReportWriter
        with patch("backend.data.openai_report_writer.AsyncOpenAI", side_effect=create_client):
            response = self.client.post("/report/generate", json=payload(), headers={
                "authorization": "Bearer test-caller-token", "x-user-id": "test-caller-identity",
            })
        self.assertEqual(response.json()["generado_con"], "openai")
        self.assertEqual(len(captured), 1)
        outgoing = captured[0]
        self.assertNotIn("test-caller-token", str(outgoing.headers))
        self.assertNotIn("test-caller-identity", str(outgoing.headers))
        self.assertNotIn("test-caller", outgoing.content.decode())
        self.assertNotIn("persona@example.test", outgoing.content.decode())

    def test_documented_three_domain_request_and_mixed_states(self):
        data = payload()
        data["resumen_dominios"].update({
            "atencion": {"nivel_senal": 1, "score_promedio": 74.5,
                         "senal": "mejora", "sesiones": 7},
            "praxias": {"nivel_senal": 1, "score_promedio": 61,
                        "senal": "atencion", "sesiones": 6},
        })
        self.assertEqual(self.post(data).status_code, 200)
        data["resumen_dominios"]["praxias"] = {"senal": "calibracion_pendiente", "sesiones": 7}
        self.assertEqual(self.post(data).status_code, 200)
        facts = self.writer.write.call_args.args[0]
        self.assertIn("esperan calibración", facts)
        self.assertIn("tendencia favorable", facts)
        self.assertNotIn("None", facts)


class LocalTemplateTests(unittest.TestCase):
    def test_all_three_domain_signal_combinations_fit_word_limit(self):
        for signals in itertools.product(SIGNAL_TEXT, repeat=3):
            summaries = tuple(DomainSummary(domain=domain, sessions=10000, signal=signal,
                                            level=3, average_score=None if signal in (
                                                "calibracion_pendiente", "insuficiente") else 100.0)
                              for domain, signal in zip(("memoria", "atencion", "praxias"), signals))
            result = local_report(ReportInput(28, summaries), "service_error")
            with self.subTest(signals=signals):
                self.assertLessEqual(len(result.text.split()), REPORT_MAX_WORDS)
                self.assertEqual(result.text.count(DISCLAIMER), 1)


class DeadlineTests(unittest.IsolatedAsyncioTestCase):
    async def test_real_eight_second_deadline_cancels_request_and_keeps_health_responsive(self):
        self.assertEqual(REPORT_TIMEOUT_SECONDS, 8.0)
        started = asyncio.Event()
        cancelled = asyncio.Event()

        async def slow_write(facts):
            started.set()
            try:
                await asyncio.sleep(60)
            finally:
                cancelled.set()

        writer = SimpleNamespace(write=slow_write)
        old = app.dependency_overrides.copy()
        app.dependency_overrides[get_report_writer] = lambda: writer
        try:
            async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app),
                                         base_url="http://test") as client:
                before = time.monotonic()
                pending = asyncio.create_task(client.post("/report/generate", json=payload()))
                await started.wait()
                health = await asyncio.wait_for(client.get("/health"), timeout=1)
                self.assertEqual(health.status_code, 200)
                response = await asyncio.wait_for(pending, timeout=9)
                elapsed = time.monotonic() - before
        finally:
            app.dependency_overrides.clear()
            app.dependency_overrides.update(old)
        self.assertGreaterEqual(elapsed, 7.9)
        self.assertLess(elapsed, 8.8)
        self.assertTrue(cancelled.is_set())
        self.assertEqual(response.json()["motivo_respaldo"], "timeout")
        self.assertTrue(response.json()["reporte_texto"].endswith(DISCLAIMER))

    async def test_cancellation_by_caller_is_not_swallowed(self):
        writer = SimpleNamespace(write=AsyncMock(side_effect=asyncio.CancelledError))
        report = ReportGenerateRequest.model_validate(payload()).to_domain()
        with self.assertRaises(asyncio.CancelledError):
            await generate_report(report, writer)


class OpenAIAdapterTests(unittest.IsolatedAsyncioTestCase):
    async def test_actual_outbound_payload_contains_only_fixed_prompt_and_validated_aggregates(self):
        captured = []

        def handler(request):
            captured.append(json.loads(request.content))
            return httpx.Response(200, json={
                "id": "test-response", "object": "chat.completion", "created": 0,
                "model": "gpt-5.6-luna", "choices": [{"index": 0, "finish_reason": "stop",
                    "message": {"role": "assistant", "content": SUCCESS_TEXT}}],
            })

        def create_client(**kwargs):
            self.assertEqual(kwargs["timeout"], 8.0)
            self.assertEqual(kwargs["max_retries"], 0)
            return AsyncOpenAI(api_key="test-not-a-real-key", timeout=kwargs["timeout"],
                               max_retries=kwargs["max_retries"],
                               http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)))

        data = payload()
        with patch("backend.data.openai_report_writer.AsyncOpenAI", side_effect=create_client):
            result = await generate_report(ReportGenerateRequest.model_validate(data).to_domain(),
                                           OpenAIReportWriter())
        self.assertEqual(result.source, "openai")
        self.assertEqual(len(captured), 1)
        outgoing = captured[0]
        self.assertFalse(outgoing["store"])
        self.assertNotIn("user", outgoing)
        self.assertNotIn("metadata", outgoing)
        self.assertEqual([m["role"] for m in outgoing["messages"]], ["system", "user"])
        self.assertIn("68,2/100", outgoing["messages"][1]["content"])
        self.assertNotIn("test-not-a-real-key", json.dumps(outgoing["messages"]))
        self.assertNotIn("session_uuid", json.dumps(outgoing))

    async def test_sdk_timeout_is_classified_and_no_key_uses_local_fallback(self):
        writer = OpenAIReportWriter()
        with patch.object(writer, "_write", side_effect=APITimeoutError(
                request=httpx.Request("POST", "https://api.openai.com"))):
            with self.assertRaises(TimeoutError):
                await writer.write("hechos")
        with patch.dict("os.environ", {}, clear=True):
            result = await generate_report(ReportGenerateRequest.model_validate(payload()).to_domain(), writer)
        self.assertEqual(result.source, "plantilla_local")
        self.assertEqual(result.fallback_reason, "service_error")

    async def test_truncated_refused_or_empty_response_uses_local_fallback(self):
        for choices in ([], [SimpleNamespace(finish_reason="stop", message=SimpleNamespace(content=SUCCESS_TEXT, refusal="refused"))], [SimpleNamespace(finish_reason="length", message=SimpleNamespace(content=SUCCESS_TEXT, refusal=None))],
                        [SimpleNamespace(finish_reason="stop", message=SimpleNamespace(content=None, refusal=None))]):
            client = AsyncMock()
            client.chat.completions.create.return_value = SimpleNamespace(choices=choices)
            context = AsyncMock()
            context.__aenter__.return_value = client
            with patch("backend.data.openai_report_writer.AsyncOpenAI", return_value=context):
                result = await generate_report(ReportGenerateRequest.model_validate(payload()).to_domain(),
                                               OpenAIReportWriter())
            self.assertEqual(result.fallback_reason, "invalid_response")


if __name__ == "__main__":
    unittest.main()
