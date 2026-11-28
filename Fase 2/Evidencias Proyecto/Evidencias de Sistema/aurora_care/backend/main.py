"""AuroraCare: scoring determinístico y redacción anónima de reportes."""

# Conserva el arranque del spike con uvicorn main:app desde backend/.
if not __package__:
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    __package__ = "backend"

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel, ConfigDict, Field, AwareDatetime, model_validator
from typing import Literal, Union, Optional

from .scoring import GAME_DOMAINS, analizar
from dotenv import load_dotenv
from .data.openai_report_writer import OpenAIReportWriter
from .presentation.report_routes import (
    get_report_writer, report_validation_error_handler, router as report_router,
)

# Carga las variables de entorno desde .env (OPENAI_API_KEY)
load_dotenv()

app = FastAPI(title="AuroraCare Backend")
app.dependency_overrides[get_report_writer] = OpenAIReportWriter
app.include_router(report_router)
app.add_exception_handler(RequestValidationError, report_validation_error_handler)

# CORS abierto para desarrollo local (Flutter corre en otro puerto/emulador).
# TODO: restringir origins antes de producción.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- MODELOS DE DATOS (Pydantic) ----------
# Siguen la estructura de payload definida en SCORING.md sección 5

GameType = Literal[
    "memorice_clasico", "memorice_secuencias", "que_cambio", "recuerde_numero",
    "secuencias_colores", "toca_correcto", "contador_objetos",
    "trazado_guiado", "conecta_puntos", "colorear_contorno",
]

class DatosValidados(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

class MetricasMemoria(DatosValidados):
    tiempo_total_seg: float = Field(ge=0)
    errores: int = Field(ge=0, strict=True)
    intentos: int = Field(ge=0, strict=True)
    tasa_acierto_pct: float = Field(ge=0, le=100)

class MetricasAtencion(DatosValidados):
    tasa_error_pct: float = Field(ge=0, le=100)
    tiempo_respuesta_ms: float = Field(ge=0)
    alcance: int = Field(ge=0, strict=True)

class MetricasPraxias(DatosValidados):
    precision_pct: float = Field(ge=0, le=100)
    correcciones: int = Field(ge=0, strict=True)
    tiempo_seg: float = Field(ge=0)

class SesionHistorial(DatosValidados):
    timestamp: AwareDatetime
    nivel: int = Field(ge=1, le=3, strict=True)
    score: float = Field(ge=0, le=100)
    game_type: Optional[GameType] = None
    tasa_acierto_pct: Optional[float] = Field(default=None, ge=0, le=100)

class SessionAnalyzeRequest(DatosValidados):
    session_uuid: Optional[str] = None
    game_type: GameType
    nivel: int = Field(ge=1, le=3, strict=True)
    timestamp: AwareDatetime
    metricas: Union[MetricasMemoria, MetricasAtencion, MetricasPraxias]
    historial_28d: list[SesionHistorial] = Field(default_factory=list)

    @model_validator(mode="after")
    def validar_dominio(self):
        dominio = GAME_DOMAINS[self.game_type]
        esperado = {"memoria": MetricasMemoria, "atencion": MetricasAtencion,
                    "praxias": MetricasPraxias}[dominio]
        if not isinstance(self.metricas, esperado):
            raise ValueError("metricas no corresponden al game_type")
        if any(s.game_type is not None and GAME_DOMAINS[s.game_type] != dominio
               for s in self.historial_28d):
            raise ValueError("historial_28d debe pertenecer al mismo dominio")
        return self

# ---------- ENDPOINTS DEL SPIKE ----------

@app.get("/health")
def health():
    """Paso 1 del spike: Flutter llama esto y debe mostrar 'OK' en pantalla."""
    return {"status": "OK"}


@app.post("/session/analyze")
def analyze_session(data: SessionAnalyzeRequest):
    """Scoring determinístico local; los juegos sin rangos esperan calibración."""
    if data.game_type != "memorice_clasico":
        raise HTTPException(status_code=422, detail={
            "code": "calibration_pending", "game_type": data.game_type,
            "message": "Rangos de normalización pendientes de calibración.",
        })
    return analizar(data)
