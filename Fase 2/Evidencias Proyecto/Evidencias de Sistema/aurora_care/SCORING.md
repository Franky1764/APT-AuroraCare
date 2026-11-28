# AuroraCare — SCORING.md — Sistema de Scoring Cognitivo Local

v1.1 · Octubre 2026 · Lógica central auditada, sin dependencia de IA externa

> **Principio rector de este documento**
> El scoring cognitivo de AuroraCare es 100% local, determinístico y auditable. No depende de OpenAI ni de ninguna IA externa. OpenAI solo recibe el resultado del scoring para redactar el texto del reporte en lenguaje natural. Este documento define todas las reglas de cálculo.

---

## 0. Cambios respecto a v1.0

| Sección | Cambio | Motivo |
| --- | --- | --- |
| §1 | El nivel (Fácil, Intermedio, Avanzado) lo elige la persona antes de cada juego. El avance de nivel pasa a ser una sugerencia. | Decisión de producto, sprint 3. |
| §2 | Nueve juegos, tres por dominio. Los tres juegos de un dominio comparten componentes y pesos, así que hay **un score por dominio**. El dominio se muestra como **Motricidad** en la interfaz; la clave interna sigue siendo `praxias`. | Alcance del MVP (ARCHITECTURE v2.2 §5.1). Praxias no es un término conocido por los adultos mayores. |
| §3.1 | Fórmula de normalización corregida y ejemplo recalculado (55,8, no 65,8). | El ejemplo de v1.0 mezclaba dos formas de la fórmula. |
| §3.2 | Se elimina la "línea base" (promedio y desviación de las primeras 5 sesiones). La calibración es el mínimo de 5 sesiones. | Estaba definida pero no intervenía en ningún cálculo. |
| §4 | La tendencia se calcula por dominio **y nivel**, y mide el cambio estimado en toda la ventana de 28 días. | Con la fórmula de v1.0 la señal ROJO era prácticamente inalcanzable. |
| §4.4 | La notificación push al cuidador exige ROJO en dos evaluaciones consecutivas de días distintos. | Evitar alarmas falsas. |
| §5 | El cliente envía el historial de 28 días en cada request. `game_type` pasa a 9 valores. | FastAPI no tiene estado ni acceso a Firestore. |
| §6 | El prompt incluye el nivel y usa "Motricidad". El límite de palabras se unifica en 150. | Coherencia con §2 y con la validación del spike. |

---

## 1. Principios del sistema de scoring

| Principio | Detalle |
| --- | --- |
| **Local y auditable** | Todas las reglas están definidas en este documento y en el código de FastAPI. Cualquier evaluador puede verificar el cálculo paso a paso. |
| **Sin diagnóstico** | El sistema produce señales de tendencia, no diagnósticos. Nunca dice "deterioro detectado". Dice "tendencia descendente en los últimos 28 días". |
| **Nivel elegido por la persona** | Antes de cada juego la persona elige Fácil, Intermedio o Avanzado. Cuando cumple el criterio de avance, el sistema le sugiere probar el siguiente nivel, pero no se lo impone. La dificultad no se adapta en tiempo real: más simple, más honesto, más auditable. |
| **Un score por dominio** | Memoria, Atención y Motricidad tienen cada uno un único score, sin importar cuál de sus tres juegos se jugó. |
| **Comparación interna** | El usuario se compara consigo mismo en el tiempo, nunca con promedios poblacionales, y solo con sus propias sesiones del mismo dominio y nivel. |
| **Mínimo 5 sesiones** | El sistema no emite señal hasta tener al menos 5 sesiones del mismo dominio y nivel dentro de la ventana. Con menos datos, la señal sería ruido estadístico. |
| **Ventana de 28 días** | El análisis de tendencia usa las últimas 4 semanas. Sesiones anteriores se archivan pero no afectan la señal activa. |

---

## 2. Dominios, métricas y juegos

### 2.1 Reglas comunes

Cada dominio define sus **componentes** y **pesos**. Cada juego traduce sus datos crudos a esos componentes (el cliente Flutter hace esa traducción, ver §5.1). Así el servidor tiene un solo calculador por dominio.

| `game_type` | Juego | Dominio (clave interna) | Nombre en la interfaz |
| --- | --- | --- | --- |
| `memorice_clasico` | Memorice clásico | `memoria` | Memoria |
| `memorice_secuencias` | Memorice de secuencias | `memoria` | Memoria |
| `que_cambio` | ¿Qué cambió? | `memoria` | Memoria |
| `secuencias_colores` | Secuencias de colores | `atencion` | Atención |
| `toca_correcto` | Toca el correcto | `atencion` | Atención |
| `contador_objetos` | Contador de objetos | `atencion` | Atención |
| `trazado_guiado` | Trazado guiado | `praxias` | Motricidad |
| `conecta_puntos` | Conecta los puntos | `praxias` | Motricidad |
| `colorear_contorno` | Colorear dentro del contorno | `praxias` | Motricidad |

En el reporte exportable para el médico, el dominio puede mostrarse como "Motricidad (praxias)".

**Rangos de normalización.** Cada componente tiene un valor `mejor` y un valor `peor` por juego y nivel. Los porcentajes usan por defecto 100/0 (o 0/100 para una tasa de error), salvo que el dueño del juego defina otro rango.

### 2.2 Dominio Memoria

| Componente | Clave en `metricas` | Peso |
| --- | --- | --- |
| Errores | `errores` | 35% |
| Tiempo total de sesión | `tiempo_total_seg` | 30% |
| Intentos | `intentos` | 20% |
| Tasa de acierto | `tasa_acierto_pct` | 15% |

| Juego | Errores | Tiempo | Intentos | Acierto |
| --- | --- | --- | --- | --- |
| Memorice clásico | pares incorrectos | desde la primera carta volteada hasta el último par | cartas volteadas en total (mínimo: 2 por cada par) | pares correctos / (pares correctos + errores) × 100 |
| Memorice de secuencias | errores de orden | tiempo total | rondas jugadas | rondas correctas / rondas jugadas × 100 |
| ¿Qué cambió? | omisiones + marcas incorrectas | tiempo total | toques totales | diferencias halladas / diferencias totales × 100 |

**Niveles — Memorice clásico** (los valores `mejor`/`peor` de Intermedio y Avanzado son una propuesta escalada desde Fácil; se calibran en la sesión con usuarios)

| Nivel | Pares | Tiempo máximo | Mejor (errores / intentos / tiempo) | Peor (errores / intentos / tiempo) | Sugerencia de avance |
| --- | --- | --- | --- | --- | --- |
| Fácil | 6 (12 cartas) | 240 s | 0 / 12 / 60 s | 15 / 30 / 240 s | Acierto ≥ 70% en 3 sesiones consecutivas |
| Intermedio | 8 (16 cartas) | 300 s | 0 / 16 / 80 s | 20 / 40 / 300 s | Acierto ≥ 70% en 3 sesiones consecutivas |
| Avanzado | 10 (20 cartas) | 360 s | 0 / 20 / 100 s | 25 / 50 / 360 s | Nivel máximo en el MVP |

### 2.3 Dominio Atención

| Componente | Clave en `metricas` | Peso |
| --- | --- | --- |
| Tasa de error | `tasa_error_pct` | 40% |
| Tiempo de respuesta promedio | `tiempo_respuesta_ms` | 35% |
| Alcance | `alcance` | 25% |

| Juego | Tasa de error | Tiempo de respuesta | Alcance |
| --- | --- | --- | --- |
| Secuencias de colores | toques incorrectos / toques totales × 100 | respuesta promedio al estímulo | longitud máxima de secuencia completada |
| Toca el correcto | errores / (aciertos + errores) × 100 | reacción promedio | racha máxima de aciertos |
| Contador de objetos | rondas mal contadas / rondas × 100 | respuesta promedio | mayor cantidad contada correctamente |

**Niveles — Secuencias de colores** (`mejor`/`peor` pendientes de completar por el dueño)

| Nivel | Longitud inicial | Velocidad del estímulo | Sugerencia de avance |
| --- | --- | --- | --- |
| Fácil | 3 elementos | 1,5 s por estímulo | 3 secuencias sin error en la misma sesión |
| Intermedio | 5 elementos | 1,0 s por estímulo | 3 secuencias sin error en la misma sesión |
| Avanzado | 7 elementos | 0,7 s por estímulo | Nivel máximo en el MVP |

### 2.4 Dominio Motricidad (clave interna `praxias`)

| Componente | Clave en `metricas` | Peso |
| --- | --- | --- |
| Precisión | `precision_pct` | 45% |
| Correcciones | `correcciones` | 30% |
| Tiempo de completitud | `tiempo_seg` | 25% |

| Juego | Precisión | Correcciones | Tiempo |
| --- | --- | --- | --- |
| Trazado guiado | % del trazo dentro de la tolerancia | veces que levanta el dedo y retoma | desde el inicio hasta levantar el dedo por última vez |
| Conecta los puntos | % del trazo dentro de la tolerancia | puntos tocados fuera de orden | tiempo total |
| Colorear dentro del contorno | % dentro del contorno | salidas del borde | tiempo total |

**Niveles — Trazado guiado** (`mejor`/`peor` pendientes de completar por el dueño)

| Nivel | Figuras | Tolerancia del trazo | Sugerencia de avance |
| --- | --- | --- | --- |
| Fácil | Línea recta y línea curva | ±15 px | Precisión ≥ 65% en 3 sesiones consecutivas |
| Intermedio | Círculo y cuadrado | ±10 px | Precisión ≥ 65% en 3 sesiones consecutivas |
| Avanzado | Espiral y figura compuesta | ±7 px | Nivel máximo en el MVP |

### 2.5 Plantilla de niveles (una por juego)

Cada juego define sus tres niveles con esta tabla. Los niveles son **configuración**, no contenido nuevo: el mismo juego con otros parámetros.

| Nivel | Parámetros del juego (2 o 3 variables) | Tiempo máximo | Mejor (por componente) | Peor (por componente) | Sugerencia de avance |
| --- | --- | --- | --- | --- | --- |
| Fácil | | | | | |
| Intermedio | | | | | |
| Avanzado | | | | | |

Los tres juegos de un dominio deben tener una dificultad comparable en el mismo nivel; si no, el score deja de ser comparable entre juegos. Eso se estima con las tablas y se ajusta con los datos de la sesión con usuarios.

### 2.6 Respiración guiada — Sin scoring

> **Sin métricas evaluativas**
> El módulo de respiración guiada no genera métricas cognitivas. Es un módulo de bienestar disponible en todos los modos. Se registra solo el evento de uso en Firebase Analytics sin identificación. No contribuye al scoring ni al reporte exportable.

---

## 3. Cálculo del score por sesión

Cada sesión genera un score normalizado de 0 a 100 en su dominio y nivel. El cálculo es el mismo para todos los dominios. El score 100 representa el mejor rendimiento posible en ese nivel.

### 3.1 Fórmula general

```
score_sesion = Σ (valor_norm × peso_componente)
```

Donde `valor_norm` se calcula así, acotado entre 0 y 100:

```
valor_norm = (peor - observado) / (peor - mejor) × 100
```

La misma fórmula sirve para componentes en que menos es mejor (errores, tiempo) y en que más es mejor (alcance, acierto), porque `mejor` y `peor` ya traen el sentido.

**Ejemplo — Memorice clásico, nivel Fácil**

Observado: 4 errores, 20 intentos (12 cartas mínimas + 4 errores × 2), 180 segundos, 60% de acierto (6 pares correctos de 10 intentos de par).

```
Errores:   (15 - 4)   / (15 - 0)   × 100 = 73.3  × 0.35 = 25.7 puntos
Tiempo:    (240 - 180) / (240 - 60) × 100 = 33.3  × 0.30 = 10.0 puntos
Intentos:  (30 - 20)  / (30 - 12)  × 100 = 55.6  × 0.20 = 11.1 puntos
Acierto:   60 (directo)                    × 0.15 =  9.0 puntos

SCORE TOTAL SESIÓN: 55.8 / 100
```

### 3.2 Calibración

El sistema no emite señal hasta tener al menos 5 sesiones del mismo dominio y nivel dentro de la ventana de 28 días. Esas primeras sesiones son el período de calibración: solo acumulan datos. La persona se compara siempre consigo misma.

---

## 4. Análisis de tendencia — ventana de 28 días

### 4.1 Qué sesiones entran

La tendencia se calcula **por dominio y nivel**. La **señal del dominio** es la del nivel con más sesiones dentro de los últimos 28 días; si hay empate, la del nivel jugado más recientemente. Si ese nivel tiene menos de 5 sesiones, la señal es GRIS.

Esto evita que una persona que pasa de Fácil a Avanzado parezca empeorar solo por cambiar de dificultad. Quien alterna niveles tarda más en juntar 5 sesiones; mientras tanto la señal queda en GRIS, que es la salida segura.

### 4.2 Cálculo — código FastAPI

```python
# scoring.py - FastAPI
import numpy as np

def calcular_tendencia(scores: list[float]) -> dict:
    n = len(scores)
    if n < 5:
        return {"senal": "insuficiente", "variacion_pct": None}

    x = np.arange(n)
    pendiente, _ = np.polyfit(x, scores, 1)
    media = max(float(np.mean(scores)), 1e-9)
    # Cambio estimado en TODA la ventana, como % del promedio
    variacion_pct = float(pendiente) * (n - 1) / media * 100

    return {
        "senal": clasificar_senal(variacion_pct),
        "variacion_pct": round(variacion_pct, 1),
    }

def clasificar_senal(v: float) -> str:
    if v > 5:
        return "mejora"
    if v >= -5:
        return "estable"
    if v >= -15:
        return "atencion"
    return "revisar"

def senal_dominio(sesiones: list[dict]) -> dict:
    """sesiones: últimos 28 días del dominio, cada una con
    'timestamp' (ISO 8601), 'nivel' y 'score'."""
    por_nivel: dict[int, list[dict]] = {}
    for s in sorted(sesiones, key=lambda s: s["timestamp"]):
        por_nivel.setdefault(s["nivel"], []).append(s)

    if not por_nivel:
        return {"senal": "insuficiente", "variacion_pct": None, "nivel_senal": None}

    nivel = max(
        por_nivel,
        key=lambda n: (len(por_nivel[n]), por_nivel[n][-1]["timestamp"]),
    )
    resultado = calcular_tendencia([s["score"] for s in por_nivel[nivel]])
    resultado["nivel_senal"] = nivel
    return resultado
```

**Casos de prueba mínimos**
- Scores `[85, 82, 79, 76, 73, 70, 67, 64]`: pendiente -3, promedio 74,5, variación -28,2% → `revisar` (ROJO). Con la fórmula de v1.0 daba -4,0% y resultaba VERDE.
- Scores constantes (por ejemplo cinco veces 70): variación 0,0% → `estable`.
- Cuatro sesiones: `insuficiente` (GRIS).

### 4.3 Clasificación de señales

| Señal | Criterio de variación | Color en UI | Mensaje para el cuidador |
| --- | --- | --- | --- |
| **VERDE — Estable** | Variación entre -5% y +5% | Verde | Sus sesiones muestran un rendimiento consistente en los últimos 28 días. |
| **AZUL — Mejora** | Variación mayor a +5% | Azul | Sus sesiones muestran una tendencia de mejora en los últimos 28 días. |
| **AMARILLO — Atención** | Variación entre -5% y -15% | Amarillo | Sus sesiones muestran una leve tendencia descendente. Se recomienda observar. |
| **ROJO — Revisar** | Variación menor a -15% | Rojo | Sus sesiones muestran una tendencia descendente sostenida. Se recomienda consultar a un profesional. |
| **GRIS — Sin datos** | Menos de 5 sesiones en el nivel con más sesiones | Gris | Aún no hay suficientes sesiones para mostrar una tendencia confiable. |

> **Advertencia — Regla crítica de lenguaje**
> Las señales NUNCA usan estas palabras: deterioro, demencia, Alzheimer, diagnóstico, problema, anormal, patológico, enfermedad. Siempre describen tendencias observadas en las sesiones, nunca estados de salud. El disclaimer del reporte recuerda al cuidador que debe consultar a un profesional de la salud para interpretación clínica.

### 4.4 Notificación push al cuidador

El dashboard muestra la señal calculada. La **notificación push** (USER_FLOWS F9, paso 5) solo se emite cuando la señal de un dominio es ROJO en **dos evaluaciones consecutivas realizadas en días distintos**. Una evaluación es el cálculo de la señal tras una sesión nueva. Si la segunda evaluación no es ROJO, no se envía nada.

Las evaluaciones consecutivas comparten casi todos los datos de la ventana, así que este filtro es moderado: reduce las alarmas por un mal día, no las elimina.

### 4.5 Umbrales provisorios

Los umbrales de ±5% y -15% son una primera estimación. Con pocas sesiones, el azar puede producir AMARILLO o ROJO. Se calibran con los datos de la sesión con usuarios (SCRUM-29) y, mientras tanto, se tratan como provisorios.

---

## 5. Estructura del payload — FastAPI

FastAPI **no tiene estado**: no guarda sesiones, no accede a Firestore y no registra el cuerpo de los requests. El cliente envía el historial que necesita en cada llamada.

### 5.1 Request — POST /session/analyze

`metricas` usa las claves del dominio (ver §2.2 a §2.4); el cliente traduce los datos crudos de cada juego. `historial_28d` contiene las sesiones del **mismo dominio** de los últimos 28 días (todos los niveles), sin incluir la sesión actual y con su score ya calculado.

```json
{
  "session_uuid": "anon-uuid-generado-local",
  "game_type": "memorice_clasico",
  "nivel": 1,
  "timestamp": "2026-10-12T10:30:00Z",
  "metricas": {
    "tiempo_total_seg": 180,
    "errores": 4,
    "intentos": 20,
    "tasa_acierto_pct": 60.0
  },
  "historial_28d": [
    { "timestamp": "2026-10-05T10:00:00Z", "nivel": 1, "score": 52.1 },
    { "timestamp": "2026-10-08T17:20:00Z", "nivel": 1, "score": 55.0 }
  ]
}
```

### 5.2 Response — POST /session/analyze

```json
{
  "score_sesion": 55.8,
  "nivel_jugado": 1,
  "sugerir_avance": false,
  "sesiones_en_ventana": 3,
  "tendencia": {
    "senal": "insuficiente",
    "variacion_pct": null,
    "nivel_senal": 1,
    "ventana_dias": 28
  }
}
```

El cliente guarda el `score_sesion` junto con `gameType` y `nivel` de la sesión, porque lo necesitará como historial en la próxima llamada. Si no hay conexión, la sesión se guarda con las métricas crudas y el score pendiente; se analiza cuando vuelva la conexión, y mientras tanto no cuenta para la tendencia.

### 5.3 Request — POST /report/generate

```json
{
  "periodo_dias": 28,
  "resumen_dominios": {
    "memoria":  { "nivel_senal": 2, "score_promedio": 68.2, "senal": "estable",  "sesiones": 8 },
    "atencion": { "nivel_senal": 1, "score_promedio": 74.5, "senal": "mejora",   "sesiones": 7 },
    "praxias":  { "nivel_senal": 1, "score_promedio": 61.0, "senal": "atencion", "sesiones": 6 }
  }
}
```

`score_promedio` y `sesiones` corresponden a las sesiones del nivel con el que se calculó la señal.

> **Nota de implementación (spike técnico, sept. 2026):** en la implementación real del spike, `/report/generate` terminó **sin** `session_uuid` en el payload — ver ARCHITECTURE.md sección 6, regla de privacidad: OpenAI no debe recibir ningún identificador, ni siquiera uno de sesión.

---

## 6. Redacción con OpenAI — HU-38

OpenAI solo redacta el reporte; no calcula scoring ni tendencias. El prompt
vigente está en `backend/data/openai_report_writer.py` (`SYSTEM_PROMPT`).
Recibe hechos construidos por `backend/domain/reports.py` a partir de campos
numéricos, dominios y señales validados. No recibe identidad, UUID, fechas
personales, historial individual ni texto libre del cliente.

La síntesis distingue los dominios y niveles disponibles, sin inferir estados
de salud, causalidad ni tendencias donde falten datos. Se solicita un texto
breve sin cifras nuevas. El servidor comprueba longitud, presencia de dominios
y lenguaje prohibido y añade por su cuenta el aviso obligatorio; así la palabra
«diagnóstico» solo se permite en ese aviso. Es una comprobación técnica básica,
no una validación clínica ni una garantía de fidelidad semántica del modelo.

El modelo por defecto conserva `gpt-5.6-luna`, usado en el spike; puede
configurarse con `OPENAI_REPORT_MODEL`. La versión HU-38 se prueba con un
transporte simulado, sin llamadas facturables; no presupone una nueva validación
del prompt contra el servicio real.

---

## 7. Plan B — plantillas locales sin OpenAI

En HU-38, FastAPI devuelve una plantilla local cuando OpenAI falla o supera
**ocho segundos totales**, sin reintentos. También la usa ante salida inválida
o cuando no hay ninguna tendencia calculada. El endpoint nunca devuelve texto
vacío para un request válido. El scoring no cambia.

Las plantillas vigentes están en `backend/domain/reports.py` (`SIGNAL_TEXT`):

| Señal | Descripción del respaldo |
| --- | --- |
| `estable` | Desempeño consistente en los ejercicios. |
| `mejora` | Tendencia favorable en los ejercicios, sin atribuir causas. |
| `atencion` | Variaciones observadas; práctica al ritmo de la persona. |
| `revisar` | Variaciones sostenidas que puede comentar con un profesional de salud. |
| `insuficiente` | Faltan sesiones comparables para describir una tendencia. |
| `calibracion_pendiente` | La práctica está registrada; puntuación y tendencia pendientes. |

El texto incluye período, dominio, sesiones y nivel/puntuación reales cuando
estén disponibles. Con cero sesiones lo indica sin atribuir una tendencia.
Todas las respuestas añaden:

> *Este reporte no constituye un diagnóstico médico. Consulte a un profesional de la salud para una evaluación completa.*

El límite de 150 palabras incluye ese aviso. El campo `generado_con` distingue
`openai` de `plantilla_local`, y `motivo_respaldo` permite conocer la causa sin
exponer errores internos del proveedor. El contrato completo está en README.md.

**Fuera de HU-38:** el respaldo adicional en Flutter cuando el servidor no es
accesible y la generación local del PDF. El spike previo validó la conexión con
OpenAI, pero no implementaba este respaldo ni el plazo de ocho segundos.

---

## 8. Pendientes de esta versión

| Pendiente | Responsable |
| --- | --- |
| Completar la plantilla de niveles (§2.5) de los 6 juegos restantes y los `mejor`/`peor` de Secuencias de colores y Trazado guiado. | Dueño de cada dominio; revisa Daniela |
| Revisar los pesos de Memoria: errores, intentos y acierto miden casi lo mismo (el número de pares correctos es fijo por nivel). | Tras la sesión con usuarios |
| Calibrar los umbrales de §4.3 y la dificultad comparable entre juegos de un mismo dominio. | Sesión con usuarios (SCRUM-29) |
| Confirmar que `Session`/`CognitiveMetrics` guardan `gameType`, `nivel` y `score_sesion`. | Daniela |
| Agregar a USER_FLOWS F4 el paso de elegir nivel, y a F9 la regla de §4.4. | Daniela |
| Validar de nuevo el prompt de §6 con nivel y "Motricidad". | Daniela / Eduardo |

---

AuroraCare · SCORING.md v1.1 · Octubre 2026 · Daniela Castillo · Duoc UC