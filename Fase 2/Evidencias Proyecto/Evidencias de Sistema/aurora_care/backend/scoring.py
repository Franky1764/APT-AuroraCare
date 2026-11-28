"""Scoring local según SCORING.md v1.1; sin estado ni servicios externos.

El historial pertenece al dominio del request. game_type es opcional para
compatibilidad con §5; sin él no se puede acreditar avance del mismo juego.
"""
from collections import Counter
from datetime import timedelta

SCORING_VERSION = "scoring-v1.1-memorice-1"
GAME_DOMAINS = {
    "memorice_clasico": "memoria", "memorice_secuencias": "memoria",
    "que_cambio": "memoria", "secuencias_colores": "atencion",
    "recuerde_numero": "memoria",
    "toca_correcto": "atencion", "contador_objetos": "atencion",
    "trazado_guiado": "praxias", "conecta_puntos": "praxias",
    "colorear_contorno": "praxias",
}
RANGES = {
    1: {"errores": (0, 15), "intentos": (12, 30), "tiempo_total_seg": (60, 240)},
    2: {"errores": (0, 20), "intentos": (16, 40), "tiempo_total_seg": (80, 300)},
    3: {"errores": (0, 25), "intentos": (20, 50), "tiempo_total_seg": (100, 360)},
}
WEIGHTS = {"errores": .35, "tiempo_total_seg": .30, "intentos": .20, "tasa_acierto_pct": .15}


def normalizar(observado, mejor, peor):
    return max(0.0, min(100.0, (peor - observado) / (peor - mejor) * 100))


def score_memorice(metricas, nivel):
    ranges = {**RANGES[nivel], "tasa_acierto_pct": (100, 0)}
    return round(sum(normalizar(metricas[k], *ranges[k]) * w for k, w in WEIGHTS.items()), 1)


def clasificar_senal(v):
    """Umbrales provisorios: >5 mejora; >=-5 estable; >=-15 atención."""
    if v > 5:
        return "mejora"
    if v >= -5:
        return "estable"
    if v >= -15:
        return "atencion"
    return "revisar"


def calcular_tendencia(scores):
    n = len(scores)
    if n < 5:
        return {"senal": "insuficiente", "variacion_pct": None}
    media = sum(scores) / n
    centro = (n - 1) / 2
    pendiente = sum((i - centro) * (s - media) for i, s in enumerate(scores)) / sum((i - centro) ** 2 for i in range(n))
    variacion = pendiente * (n - 1) / max(media, 1e-9) * 100
    return {"senal": clasificar_senal(variacion), "variacion_pct": round(variacion, 1)}


def analizar(data):
    score = score_memorice(data.metricas.model_dump(), data.nivel)
    inicio = data.timestamp - timedelta(days=28)
    sesiones = [s.model_dump() for s in data.historial_28d if inicio <= s.timestamp <= data.timestamp
                and s.game_type == data.game_type]
    sesiones.append({"timestamp": data.timestamp, "nivel": data.nivel, "score": score,
                     "game_type": data.game_type, "tasa_acierto_pct": data.metricas.tasa_acierto_pct})
    sesiones.sort(key=lambda s: s["timestamp"])
    conteo = Counter(s["nivel"] for s in sesiones)
    nivel = max(conteo, key=lambda n: (conteo[n], max(s["timestamp"] for s in sesiones if s["nivel"] == n)))
    tendencia = calcular_tendencia([s["score"] for s in sesiones if s["nivel"] == nivel])
    ultimas = [s for s in sesiones if s["nivel"] == data.nivel and s.get("game_type") == data.game_type][-3:]
    avance = data.nivel < 3 and len(ultimas) == 3 and all(s.get("tasa_acierto_pct") is not None and s["tasa_acierto_pct"] >= 70 for s in ultimas)
    return {"score_sesion": score, "nivel_jugado": data.nivel, "sugerir_avance": avance,
            "sesiones_en_ventana": len(sesiones), "scoring_version": SCORING_VERSION,
            "tendencia": {**tendencia, "nivel_senal": nivel, "ventana_dias": 28}}
