# AuroraCare — ARCHITECTURE.md — Documento Maestro de Arquitectura v2.4

Octubre 2026 · Uso interno del equipo y Claude Code

**Plataforma:** Android · Google Play MVP diciembre 2026
**Stack:** Flutter · Firebase · FastAPI · OpenAI
**Equipo:** Daniela Castillo (líder) · Benjamín Valle · Eduardo Villanueva
**Marco legal:** Ley 21.719 Chile · Privacy by Design

> ⚠️ **Instrucción para Claude Code**
> Este documento es el contexto de arquitectura de AuroraCare. Pégalo al inicio de cada sesión de desarrollo. Toda decisión técnica debe respetar: (1) separación de identidad y datos comportamentales, (2) arquitectura de capas, (3) Riverpod como gestor de estado, (4) dos modos de uso del adulto mayor (seguimiento personal y con cuidador), (5) cumplimiento Ley 21.719. Ningún cambio a capas `data/` o `domain/` sin revisión de Daniela.

---

## 1. Visión y propuesta de valor

AuroraCare es una aplicación móvil Android de estimulación cognitiva para personas mayores. El adulto mayor decide cómo usarla: seguimiento personal de su propio progreso o, además, vinculación con un cuidador. No emite diagnósticos médicos y no vincula la identidad del usuario a sus datos de comportamiento.

| | |
| --- | --- |
| **Problema** | El deterioro cognitivo en adultos mayores se detecta tarde. Las familias no tienen herramientas accesibles de seguimiento preventivo. Y los adultos mayores no tienen herramientas de estimulación cognitiva diseñadas para su contexto. |
| **Solución** | Estimulación cognitiva en dominios clave (memoria, atención, motricidad) + seguimiento de tendencias + reporte exportable para el médico + dashboard opcional para cuidador. |
| **No es** | Un dispositivo médico. No diagnostica. No reemplaza al médico ni al psicólogo. Es una herramienta de bienestar, estimulación y acompañamiento cognitivo. |
| **Usuario 1** | Adulto mayor — Android gama media-baja. Puede usarla solo o asistido en talleres y clubes. |
| **Usuario 2** | Cuidador — accede solo si el adulto mayor lo vincula. Ve señales interpretadas, no datos crudos. |
| **Entrega** | Google Play Store — MVP funcional y publicado, diciembre 2026. |
| **Destino** | Transferencia tecnológica a la Municipalidad de Huechuraba (DIDECO), con proyección de expansión a otras municipalidades. |

---

## 2. Modos de uso — decisión del adulto mayor

El adulto mayor elige su modo de uso después de registrarse y puede cambiarlo en cualquier momento. El consentimiento es granular — cada modo activa solo los datos que requiere. Mientras no elige, `currentMode` vale 0.

| Modo | Descripción | Datos que se generan |
| --- | --- | --- |
| **Seguimiento personal** (valor interno 2) | Registra las métricas de sus sesiones para que vea su propio progreso y sus tendencias en el tiempo. Sin cuidador. | UUID anónimo + métricas de sesión en Firestore. Requiere consentimiento explícito. |
| **Con cuidador** (valor interno 3) | Todo lo del seguimiento personal más vinculación QR con un cuidador que recibe señales de tendencia. | UUID + métricas + alertas en Firestore. Consentimiento granular en dos pasos. |

No existe un modo de uso sin registro de métricas: el antiguo "Modo 1" (estimulación libre) se eliminó (ver §12, punto 8). Los valores internos 2 y 3 se mantienen para no migrar datos ni código ya probado; en pantallas y documentos se usan los nombres.

> 🔑 **Regla de oro de los modos**
> Solo el adulto mayor puede iniciar el cambio de modo y el vínculo con el cuidador. El cuidador nunca puede solicitar acceso. El adulto mayor puede desvincularse en cualquier momento desde la app.

---

## 3. Stack tecnológico

| | |
| --- | --- |
| **Flutter 3.x** | Framework principal. Compila a Android nativo. Un solo codebase para el equipo. |
| **Riverpod 2.x** | Gestión de estado. Inmutable, testeable, explícito. Estándar del equipo — no usar Provider ni Bloc. |
| **Firebase Auth** | Autenticación. Solo almacena email/UID. Nunca vinculado a métricas cognitivas. |
| **Cloud Firestore** | Base de datos. Colecciones separadas para identidad y métricas. Guarda el perfil cognitivo anónimo y las sesiones de juego. |
| **Firebase Analytics** | Analítica de uso anonimizada. Activa siempre. Sin datos identificables ni métricas de sesión. |
| **Firebase Storage** | Assets de los juegos. Sin datos personales. |
| **Python 3.11 + FastAPI** | Backend de análisis, sin estado. Recibe métricas anonimizadas y el historial de 28 días que envía el cliente, aplica scoring local, genera reporte con OpenAI. No guarda sesiones ni accede a Firestore. |
| **OpenAI API** | Solo genera texto interpretable del reporte. NO analiza cognición. La lógica de scoring es 100% local. |
| **GitHub** | Control de versiones. Repositorio privado (`AuroraCare` — código y documentación técnica de trabajo; `APT-AuroraCare` — documentación académica, nunca mezclados). Ramas por feature, PR obligatorio para merge a main. |

> 🔒 **Regla crítica — OpenAI**
> OpenAI recibe solo texto plano generado por el scoring local (ej: "Memoria: nivel intermedio, score promedio 68.2, tendencia estable, 8 sesiones registradas"). NUNCA recibe nombre, RUT, UUID ni historial personal. El prompt debe auditarse antes de cada envío.

---

## 4. Arquitectura de capas — Flutter

AuroraCare usa arquitectura en capas estricta. Cada integrante del equipo tiene responsabilidad sobre capas específicas. Mezclar responsabilidades entre capas está prohibido sin revisión de Daniela.

| Capa | Responsabilidad | Responsable |
| --- | --- | --- |
| **presentation/** | Pantallas, widgets, controladores Riverpod. Todo lo visual e interactivo. | Benjamín (módulo adulto mayor) · Eduardo (módulo cuidador) |
| **domain/** | Entidades, casos de uso, interfaces de repositorio. Lógica de negocio pura, sin dependencias externas. | Daniela — revisión obligatoria en todo PR |
| **data/** | Implementación de repositorios, modelos Firestore, llamadas a FastAPI. | Daniela — revisión obligatoria en todo PR |
| **core/** | Constantes, tema visual, router, utilidades, manejo de errores centralizado. | Daniela |

### 4.1 Estructura de carpetas

```
lib/
  core/
    constants/        → colores, strings, rutas de navegación
    theme/             → tema visual AuroraCare (tipografía, colores, botones)
    utils/             → helpers, formatters, extensiones
    errors/            → manejo centralizado de errores y excepciones
    router/            → GoRouter — navegación declarativa

  data/
    models/            → UserModel, SessionModel, AlertModel...
    repositories/      → implementación concreta (FirebaseAuthRepo, FirestoreRepo...)
    sources/           → firebase_source.dart, api_source.dart

  domain/
    entities/          → entidades de negocio puras (User, Session, CognitiveScore...)
    repositories/      → interfaces abstractas (contratos)
    usecases/          → StartSession, FinishSession, LinkCaregiver, GenerateReport, ExportReport...

  presentation/
    onboarding/        → welcome, disclaimer médico (F1), selección de modo (F3)
    auth/
      elder/           → login (F2), registro (F1) del adulto mayor
      caregiver/       → registro (F7) y espera del cuidador
    games/             → los 9 juegos (3 por dominio) y la selección de nivel (F4)
      shared/          → cascarón común: selector de nivel, tiempo, salida con confirmación, guardado y resultado
    breathing/         → respiración guiada — sin score (F5)
    progress/          → progreso personal del adulto mayor (F6)
    caregiver_dashboard/
                       → dashboard (F9), vínculo QR (F8)
    reports/           → reporte exportable para médico
    privacy/           → ARCO (F10), desvinculación (F11)
    profile/
    shared/            → widgets reutilizables, componentes accesibles

  main.dart
```

**Cascarón de juego.** Cada juego es una `GameDefinition` más un widget que, al terminar, llama a `run.finish(métricas)`. El cascarón (`presentation/games/shared/`) se encarga de elegir el nivel, mostrar el tiempo transcurrido, pedir confirmación al salir, guardar la sesión con `FinishSession`, analizarla y mostrar un resultado siempre positivo, sin score visible. Los juegos no escriben en Firestore ni llaman a FastAPI.

---

## 5. Módulos del MVP

### 5.1 Actividades cognitivas — núcleo del MVP

**Responsable por dominio:** Benjamín — Memoria · Eduardo — Atención · Daniela — Motricidad.

El MVP incluye **9 juegos, 3 por dominio**. Los tres juegos de un dominio comparten componentes y pesos de scoring, por lo que hay **un score por dominio** (ver SCORING.md v1.1 §2). La persona elige el nivel (Fácil, Intermedio o Avanzado) antes de cada juego; los niveles son configuración del mismo juego, no contenido nuevo.

En la interfaz el tercer dominio se muestra como **Motricidad**. La clave interna (API, Firestore, SCORING.md) sigue siendo `praxias`.

| Dominio | Juego | Descripción | Métricas capturadas |
| --- | --- | --- | --- |
| **Memoria** | Memorice clásico | Pares de imágenes boca abajo — encontrar los pares | Tiempo total, errores, intentos, tasa de acierto |
| **Memoria** | Memorice de secuencias | Se muestra una secuencia de imágenes — reproducirla en orden | Errores de orden, tiempo de respuesta, longitud de secuencia |
| **Memoria** | ¿Qué cambió? | Dos imágenes casi idénticas — identificar las diferencias | Diferencias encontradas, tiempo, omisiones |
| **Atención** | Secuencias de colores | Replicar secuencia de estímulos visuales en el mismo orden | Tiempo de respuesta, tasa de error, longitud alcanzada |
| **Atención** | Toca el correcto | Aparecen objetos en pantalla — tocar solo los que cumplen una condición | Aciertos, errores, tiempo de reacción promedio |
| **Atención** | Contador de objetos | Objetos aparecen brevemente en pantalla — contar cuántos había | Precisión del conteo, tiempo de respuesta |
| **Motricidad** (`praxias`) | Trazado guiado | Trazar figuras simples con el dedo siguiendo el contorno | Precisión del trazo, tiempo, número de correcciones |
| **Motricidad** (`praxias`) | Conecta los puntos | Unir puntos numerados en orden para formar una figura | Orden correcto, precisión del trazo, tiempo total |
| **Motricidad** (`praxias`) | Colorear dentro del contorno | Tocar dentro de una figura sin salirse del borde | Porcentaje dentro del contorno, tiempo, salidas del borde |
| **Respiración** | Respiración guiada | Animación de expansión/contracción con instrucciones de texto | Sin métricas evaluativas. Solo evento de uso en Analytics. |

La traducción de estos datos crudos a los componentes comunes de cada dominio está en SCORING.md v1.1 §2.

### 5.2 Sistema de reporte para médico (reemplaza MoCA)

AuroraCare no implementa el MoCA ni ningún instrumento diagnóstico licenciado. En cambio, genera un reporte de tendencias cognitivas exportable que el adulto mayor puede compartir con su médico o psicólogo.

- **Contenido del reporte** — tendencias por dominio (memoria, atención, motricidad) en las últimas 4 semanas, indicando el nivel con el que se calculó cada señal. Para el lector clínico el dominio puede mostrarse como "Motricidad (praxias)".
- **Formato** — PDF generado localmente en el dispositivo — no se almacena en la nube
- **Texto interpretable** — generado por OpenAI a partir del scoring local — en lenguaje claro, sin tecnicismos
- **Disclaimer obligatorio** — el reporte no constituye diagnóstico. Debe ser interpretado por un profesional de la salud
- **Activación** — disponible en ambos modos

### 5.3 Módulos completos del MVP

| | |
| --- | --- |
| **Auth + modos** | Registro, login, consentimiento de métricas explícito antes de la primera sesión, selección y cambio de modo (Seguimiento personal o Con cuidador) en cualquier momento. |
| **Juegos cognitivos** | 9 juegos, 3 por dominio: Memoria (Memorice clásico, Memorice de secuencias, ¿Qué cambió?), Atención (Secuencias de colores, Toca el correcto, Contador de objetos) y Motricidad (Trazado guiado, Conecta los puntos, Colorear dentro del contorno). Nivel Fácil, Intermedio o Avanzado elegido por la persona. Cada sesión captura métricas. |
| **Respiración guiada** | Módulo de bienestar. Sin métricas evaluativas. |
| **Progreso personal** | Visualización de tendencias propias del adulto mayor. |
| **Reporte exportable** | PDF local con tendencias interpretadas. Para compartir con médico. |
| **Dashboard cuidador** | Señales de tendencia interpretadas. Sin datos crudos. Solo en el modo Con cuidador. |
| **Vínculo QR** | Iniciado exclusivamente por el adulto mayor. El cuidador no puede solicitar acceso. |
| **ARCO completo** | Acceso, Rectificación, Cancelación y Oposición. Eliminar cuenta borra UUID y métricas asociadas. |
| **Disclaimer médico** | Pantalla obligatoria en onboarding. Sin aceptación explícita no hay acceso a la app. |

> ⛔ **Fuera del MVP — v1.1 o posterior**
> Lenguaje cognitivo · Múltiples cuidadores simultáneos · Panel web del cuidador · Gamificación y logros · Integración con sistema de salud · Citas médicas · MoCA u otros instrumentos diagnósticos licenciados · Versión iOS · Recuperación del UUID anónimo entre dispositivos (hoy el UUID queda atado al dispositivo) · Reintento automático del análisis de sesiones jugadas sin conexión.

---

## 6. Privacidad por diseño — reglas absolutas

> 🔒 **Ley 21.719 — Vigente desde diciembre 2026**
> AuroraCare cumple la Ley 21.719 desde el primer commit. Estas reglas no son opcionales ni negociables. Ningún cambio a la arquitectura de privacidad sin revisión y aprobación de Daniela.

| | |
| --- | --- |
| **Identidad separada** | Firebase Auth maneja identidad (email, UID). Firestore maneja comportamiento (métricas). NUNCA en el mismo documento ni colección. |
| **UUID anónimo** | Al elegir su modo (Seguimiento personal o Con cuidador) se genera un UUID local en el dispositivo. Es el único vínculo entre sesiones. No se almacena nombre ni email en Firestore. |
| **Firebase Analytics** | Activo siempre. Solo registra eventos agregados (módulo abierto, sesión iniciada). Sin UUID, sin métricas de sesión, sin identificación posible. |
| **Consentimiento granular** | Seguimiento personal: consentimiento de métricas, registrado de forma explícita antes de la primera sesión. Con cuidador: consentimiento de métricas + consentimiento de vínculo con cuidador. Dos pasos independientes. |
| **Cifrado en tránsito** | Toda comunicación Flutter ↔ Firebase y Flutter ↔ FastAPI usa HTTPS/TLS. Sin excepciones. |
| **Reporte local** | Los reportes PDF se generan en el dispositivo. No se almacenan en la nube ni se envían a servidores. |
| **Derechos ARCO** | Flujo completo en la app. Cancelación elimina UUID y todas las métricas asociadas en Firestore. El email en Firebase Auth se elimina por separado. |
| **FastAPI sin estado** | FastAPI no guarda sesiones, no accede a Firestore y no registra el cuerpo de los requests. El historial que necesita para la tendencia lo envía el cliente en cada llamada. |
| **OpenAI sin PII** | Ningún dato personal ni UUID llega a OpenAI. Solo métricas agregadas en texto plano. Confirmado en la práctica en el spike técnico (ver sección 10.1) — el payload de `/report/generate` no incluye `session_uuid` ni ningún otro identificador. |

---

## 7. Estructura de datos — Firestore

Todo juego guarda su sesión en Firestore, dentro del perfil cognitivo anónimo. No hay uso sin registro de métricas.

| | |
| --- | --- |
| **users/{uid}** | Perfil básico: displayName, createdAt, consentGiven, consentDate, currentMode (0 = aún no elige; 2 o 3). Sin métricas. Sin UUID cognitivo. |
| **cognitive_profiles/{uuid}** | Perfil cognitivo anónimo: uuid (generado local), deviceId, createdAt, activeMode. Sin nombre ni email. |
| **cognitive_profiles/{uuid}/sessions/{sessionId}** | Métricas por sesión: uuid, domain, gameType, nivel, startTime, endTime, metrics{}, scoreSesion (ausente si la sesión aún no se analizó). Sin identidad. |
| **caregiver_links/{linkId}** | Vínculo: adultUUID, caregiverUID, linkedAt, status. Iniciado solo por adulto mayor. |
| **alerts/{alertId}** | Señales para cuidador: uuid, type, level, generatedAt, message. Sin datos crudos de sesión. La notificación push solo se emite con señal ROJO en dos evaluaciones consecutivas de días distintos (SCORING.md §4.4). Hoy nadie puede crear alertas (`create: false`); falta decidir qué componente con credenciales de servidor las escribe, antes de F9. |

> **Nota (sept. 2026):** `caregiver_links` y una futura colección `caregiver_invites` quedan con reglas de seguridad bloqueadas (`allow read, write: if false`) hasta resolver el diseño completo de F8 en Sprint 3.

> **Consulta de historial:** la lectura de sesiones por dominio y ventana de fechas requiere un índice compuesto en la colección `sessions` (campos `domain` y `startTime`). Ya está creado en el proyecto `duocauroracare`; si se recrea el proyecto, Firestore mostrará un enlace para crearlo con un clic.

### 7.1 Reglas de seguridad Firestore vigentes (publicadas el 11 de octubre de 2026)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    match /cognitive_profiles/{uuid} {
      allow get, create, update, delete: if request.auth != null;
      allow list: if false;

      match /sessions/{sessionId} {
        allow read, delete: if request.auth != null;
        allow create: if request.auth != null
                      && request.resource.data.uuid == uuid;
        allow update: if request.auth != null
                      && resource.data.uuid == uuid
                      && request.resource.data.uuid == uuid;
      }
    }

    match /alerts/{alertId} {
      allow read: if request.auth != null
                  && resource.data.caregiverUID == request.auth.uid;
      allow create, update, delete: if false;
    }

    // BLOQUEADAS - pendiente de diseño para Sprint 3 (F8 - Vínculo QR)
    match /caregiver_links/{linkId} {
      allow read, write: if false;
    }

    match /caregiver_invites/{inviteId} {
      allow read, write: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**Cómo se protegen las sesiones.** El token de Firebase Auth no lleva ningún dato del UUID (la identidad y el comportamiento están separados a propósito), así que las reglas no pueden verificar a quién pertenece cada sesión. La protección es que el UUID actúa como llave: es un UUID v4 aleatorio que no sale del dispositivo, nadie puede listar los perfiles y las sesiones solo se alcanzan conociendo la ruta. Limitación: quien conozca un UUID y tenga sesión iniciada puede leer y modificar esas sesiones. Por eso el diseño de F8 debe entregar al cuidador solo señales, nunca el UUID. Pendientes: activar App Check y versionar estas reglas en el repo (`firestore.rules`) para que los cambios pasen por PR.

---

## 8. Backend — FastAPI

### 8.1 Endpoints MVP

| | |
| --- | --- |
| **POST /session/analyze** | Recibe las métricas de la sesión (ya traducidas a los componentes del dominio), el nivel y el historial de 28 días del dominio. Aplica scoring local y retorna el score de la sesión, la sugerencia de avance de nivel y la señal de tendencia. Sin estado. |
| **POST /report/generate** | Recibe scoring calculado, llama a OpenAI, retorna texto interpretable del reporte para PDF. |
| **GET /health** | Health check. Flutter verifica conexión antes de cada análisis. |

### 8.2 Flujo de análisis

1. Flutter captura métricas de sesión según el juego y las traduce a los componentes comunes del dominio (SCORING.md §2)
2. Flutter envía a FastAPI las métricas, el nivel y el historial de 28 días del dominio — solo UUID de sesión, nunca nombre ni email
3. Scoring local calcula el score y la señal — algoritmo definido en SCORING.md — sin IA externa
4. FastAPI devuelve el score y la señal; Flutter guarda el score en la sesión para usarlo como historial en la próxima llamada
5. Si se solicita reporte — FastAPI llama a OpenAI con métricas agregadas en texto plano
6. OpenAI retorna texto interpretable — FastAPI lo devuelve a Flutter para generar el PDF local

FastAPI no guarda sesiones ni consulta Firestore. Si no hay conexión, la sesión se guarda con las métricas crudas y el score pendiente, y se analiza cuando vuelva la conexión (el reintento automático queda para v1.1).

> 📌 **Decisión de arquitectura aprobada — no revertir**
> OpenAI es una herramienta de redacción, no el cerebro analítico. El scoring cognitivo es 100% local y auditable en SCORING.md. Esta decisión fue revisada y aprobada formalmente, y validada en la práctica mediante el spike técnico (sección 10.1). Cambiarla requiere justificación documentada y aprobación de Daniela.

---

## 9. Equipo y división de trabajo

| | |
| --- | --- |
| **Daniela Castillo (Líder técnica)** | Arquitectura completa · Capas core, data y domain · Backend FastAPI · Firebase rules · Privacy by Design · Revisión de PRs en capas críticas · Decisiones de privacidad · Coordinación con Municipalidad de Huechuraba (DIDECO) |
| **Benjamín Valle** | Presentación — módulo adulto mayor: onboarding, selección de modo, juegos cognitivos, respiración guiada, pantallas de progreso personal, widgets accesibles |
| **Eduardo Villanueva** | Presentación — módulo cuidador: dashboard de señales, vínculo QR, alertas, reporte exportable, flujo ARCO |

> 📋 **Reglas de trabajo en equipo**
> 1. Nunca hacer push directo a main — siempre rama + PR.
> 2. Cada PR requiere revisión de al menos una compañera.
> 3. Cambios en capas data/ o domain/ requieren revisión de Daniela.
> 4. Cambios en reglas de Firestore o en arquitectura de privacidad requieren aprobación de Daniela.
> 5. Documentar cada decisión importante en este archivo — versionar con fecha.

Ver también `Flujo_Trabajo_Git_AuroraCare.md` para el detalle paso a paso del flujo de ramas y Pull Requests.

---

## 10. Spike técnico — Semana 1 (22 agosto)

Antes de construir cualquier pantalla, validar que la integración completa funciona. Criterio de éxito: una pantalla Flutter muestra texto generado por OpenAI a través de FastAPI, usando métricas de prueba anonimizadas.

- **Paso 1** — Flutter: botón que llama a GET /health y muestra 'OK' en pantalla
- **Paso 2** — FastAPI POST /session/analyze: recibe JSON de prueba, retorna scoring calculado
- **Paso 3** — FastAPI POST /report/generate: recibe scoring, llama a OpenAI, retorna texto
- **Paso 4** — Flutter muestra el texto retornado en pantalla — fin del spike

> 🚨 **Plan B — si el spike falla en semana 1**
> Si FastAPI + OpenAI no funciona en 5 días: eliminar OpenAI del MVP y generar el texto del reporte con plantillas locales en Flutter. El scoring cognitivo no cambia — solo el formato del reporte cambia de texto generado por IA a texto de plantilla fija. Esta decisión debe tomarse antes del domingo 27 de agosto, no después.

### 10.1 Resultado del spike — Validado ✅

**Fecha de validación:** 4 de septiembre de 2026

El spike técnico se ejecutó y validó exitosamente, cumpliendo el criterio de éxito definido arriba: una pantalla Flutter mostró texto generado por OpenAI a través de FastAPI, usando métricas de prueba anonimizadas.

**No fue necesario activar el Plan B** (plantillas locales) — la integración Flutter → FastAPI → OpenAI funcionó de punta a punta.

| Paso | Resultado |
| --- | --- |
| 1. `GET /health` | OK — FastAPI responde correctamente |
| 2. `POST /session/analyze` | OK — scoring simplificado de prueba calculado y devuelto |
| 3. `POST /report/generate` | OK — modelo `gpt-5.6-luna` generó texto de reporte respetando todas las reglas de lenguaje (sin palabras prohibidas, con disclaimer médico, bajo 150 palabras) |
| 4. Flutter muestra el texto en pantalla | OK — confirmado visualmente en emulador Android (Medium_Phone_API_36.1) |

**Nota de arquitectura confirmada en la práctica:** el emulador Android no resuelve `localhost`/`127.0.0.1` hacia la máquina host — requiere la dirección especial `10.0.2.2`. Esto queda documentado en el código (`lib/main.dart`, constante `baseUrl` en la versión del spike) para que el equipo no repita el mismo diagnóstico. Si en el futuro se prueba en un dispositivo físico (USB o WiFi), esta dirección debe cambiar a la IP real de la máquina host en la red local.

**Nota de proceso (sept. 2026):** tras validar el spike, la pantalla de prueba (`SpikeScreen`) fue reemplazada por la estructura real de capas (ver sección 4.1). El código del spike queda disponible en el historial de git de la rama `main`/`develop` si se necesita consultar, pero no se mantiene como pantalla activa — su propósito (validar la integración) ya se cumplió y quedó documentado aquí.

**Próximo paso:** con el spike validado, el desarrollo continúa con la estructura de carpetas por capas (sección 4) y la integración de Firebase para los flujos F1-F2 (registro y login del adulto mayor).

---

## 11. Estándares de código y accesibilidad

| | |
| --- | --- |
| **Lenguaje** | Dart (Flutter) + Python (FastAPI). Comentarios de lógica de negocio en español, código en inglés. |
| **Nombrado** | camelCase para variables/funciones · PascalCase para clases · snake_case para archivos. |
| **Estado** | Riverpod exclusivamente. No usar setState() fuera de widgets simples sin lógica de negocio. |
| **Commits** | Convención: feat: / fix: / docs: / refactor: / test:  Ejemplo: feat: agregar juego memorice |
| **Ramas** | main (producción) · develop (integración) · feature/nombre-feature (desarrollo) |
| **Fuente mínima** | 18sp en todo texto visible. Títulos 22sp mínimo. |
| **Contraste** | Mínimo 4.5:1 para texto normal. 3:1 para texto grande. Verificar con herramienta antes de PR. |
| **Botones** | Área táctil mínima 48x48dp. Texto de botón descriptivo — nunca solo un ícono sin label. |
| **Lenguaje UX** | Sin tecnicismos. Sin anglicismos. Texto en español claro, frases cortas, verbos en infinitivo. |
| **Rendimiento** | Optimizar assets para gama media-baja. Probar en dispositivo físico real, no solo emulador. |

---

## 12. Registro de decisiones

### Sprint 3 (5 de octubre de 2026)

1. **Alcance de juegos:** el MVP incluye 9 juegos (3 por dominio) con **un score por dominio**. Los tres juegos de un dominio comparten componentes y pesos (SCORING.md v1.1 §2).
2. **Nombre del tercer dominio:** en la interfaz se muestra **Motricidad**, porque "praxias" no es un término conocido por los adultos mayores. La clave interna (API, Firestore, SCORING.md) sigue siendo `praxias`. El reporte para el médico puede mostrar "Motricidad (praxias)".
3. **Niveles:** la persona elige Fácil, Intermedio o Avanzado antes de cada juego. El avance de nivel es una sugerencia, no un bloqueo. La dificultad no se adapta en tiempo real.
4. **Tendencia:** se calcula por dominio y nivel, y mide el cambio estimado en la ventana de 28 días. La señal del dominio es la del nivel con más sesiones en la ventana; con menos de 5 sesiones en ese nivel la señal es GRIS.
5. **Alertas:** la notificación push al cuidador exige señal ROJO en dos evaluaciones consecutivas de días distintos. Los umbrales de las señales son provisorios y se calibran con la sesión con usuarios (SCRUM-29).
6. **Historial:** FastAPI no tiene estado. El cliente envía en cada request las sesiones de los últimos 28 días del dominio, con su score ya calculado. FastAPI no guarda ni registra el cuerpo del request.
7. **Correcciones a SCORING:** la fórmula de normalización pasa a `(peor − observado) / (peor − mejor) × 100` (el ejemplo de v1.0 daba 65,8 y el resultado correcto es 55,8) y se elimina la "línea base", que estaba definida pero no intervenía en ningún cálculo.

### Reunión de equipo (6 de octubre de 2026) y base de juego (11 de octubre de 2026)

8. **Se elimina el Modo 1 (estimulación libre):** no genera datos trazables ni aporta al seguimiento, que es el propósito del producto. Quedan dos modos: Seguimiento personal (valor interno 2) y Con cuidador (valor interno 3). Todo juego guarda sesión y requiere consentimiento de métricas explícito antes de la primera sesión. `currentMode` vale 0 hasta que la persona elige.
9. **Las sesiones pasan a `cognitive_profiles/{uuid}/sessions`:** el token de Firebase Auth no puede llevar el UUID sin romper la separación entre identidad y comportamiento, así que las reglas de la colección `sessions` de primer nivel nunca permitían leer el historial. Con la subcolección, el UUID funciona como llave de acceso. Reglas publicadas el 11 de octubre de 2026 (§7.1). Pendientes: App Check y versionar las reglas en el repo.

### Flujos de usuario v1.1 (12 de octubre de 2026)

10. **Cancelación de cuenta, borrado desde la app (MVP):** Firestore no elimina subcolecciones al borrar el documento padre, así que la app borra explícitamente, en este orden: reautenticación; marca `deletionPending` en `users/{uid}` (que no contiene el UUID); sesiones por lotes de hasta 500; `cognitive_profiles/{uuid}`; `users/{uid}`; y al final la cuenta de Firebase Auth. Mientras la cuenta exista, la app retoma un borrado interrumpido. Se descartaron por ahora la función en la nube (exige plan Blaze) y un endpoint en FastAPI (contradice "sin estado" y obliga a guardar una credencial de administrador). Límite conocido: las reglas bloquean que la app borre `alerts` y `caregiver_links`, así que ese borrado, junto con las alertas, pasa a un componente con credenciales de servidor. Se decide en conjunto con quién escribe las alertas, antes de F9.
11. **Consentimiento de métricas obligatorio para jugar, y Oposición (ARCO) como retiro de ese consentimiento:** coherente con la decisión 8, no existe uso de los juegos sin registro de métricas. El consentimiento se guarda en `users/{uid}` (`consentGiven`, `consentDate`) y se exige en la entrada común de todos los juegos (`GameLevelScreen`): si no está dado, se muestra la pantalla de consentimiento (F4 paso 0) y, si la persona elige "Ahora no", los juegos siguen cerrados (la Respiración guiada no depende de él). Retirar el consentimiento (Oposición) lo deja en falso sin eliminar la cuenta, con opción de borrar el historial, y es reversible. El aviso médico (F1 paso 4) es un campo distinto, `disclaimerAcceptedAt`, y no equivale al consentimiento de métricas.

---

AuroraCare · ARCHITECTURE.md v2.4 · Octubre 2026 · Daniela Castillo, Benjamín Valle, Eduardo Villanueva · Duoc UC
Actualización F8 (noviembre de 2026): el protocolo vigente del QR se describe
en README, sección «Invitaciones QR reales». Los vínculos contienen `adultUID`
y `caregiverUID` de autenticación, no `adultUUID` cognitivo. La generación y
el escaneo se conectan por un token opaco, con caducidad y uso único validados
en servidor. Esto no autoriza leer sesiones ni almacena una asociación
cuenta-perfil cognitivo en la nube. Los bloques históricos de reglas anteriores
no deben publicarse: la fuente versionada es `firestore.rules`.
