# aurora_care

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Análisis real de sesiones

Flutter envía las métricas medidas por los juegos a `POST /session/analyze`.
FastAPI calcula el resultado determinísticamente según `SCORING.md`, sin usar
OpenAI para scoring. El request no contiene identidad ni UUID del perfil.

Desde la raíz, con las dependencias del backend instaladas:

```sh
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

Configurar explícitamente el servidor al iniciar Flutter (usar HTTPS en un
entorno desplegado):

```sh
flutter run --dart-define=AURORACARE_API_BASE_URL=https://servidor-del-proyecto
```

En el emulador Android, el host de desarrollo se alcanza con
`http://10.0.2.2:8000`. El tráfico HTTP se permite únicamente en la variante
Android debug; en dispositivo físico se usa la dirección del equipo servidor.
No usar datos personales reales en un entorno de desarrollo sin protección.
La clave OpenAI no es necesaria para `/health` ni `/session/analyze`.

### Cobertura y datos históricos

- Motricidad permite elegir entre «Ejercitar mis movimientos» y «Practicar con
  mi teléfono». El primer ejercicio del teléfono, «Tocar botones e imágenes»,
  propone seis acciones sin límite de tiempo, con avance manual y pausa.
  Guarda acciones completadas, toques dentro/fuera y tamaños de los elementos
  como `phone-touch-v1`. Estas observaciones no se envían al scoring cognitivo
  ni se mezclan con tiempos de reacción o precisión de trazado.
- «Deslizar entre imágenes» permite recorrer tres ilustraciones locales y
  volver a la primera, sin acceso a fotos personales ni requisito de velocidad.
  Registra cuatro cambios de imagen, gestos intentados y cambios con un botón
  de apoyo por separado (`phone-swipe-v1`). La distancia requerida depende del
  ancho de la imagen y de la opción elegida; no constituye un umbral clínico.
- «Arrastrar a su lugar» practica mantener presionada una imagen, moverla y
  soltarla dentro de un recuadro. El resaltado y la aceptación al soltar usan
  la misma regla de superposición. Cada colocación deja lista la siguiente
  imagen sin botones intermedios. Se guardan intentos, arrastres logrados,
  colocaciones con apoyo y tamaños (`phone-drag-v1`), sin score cognitivo.
- «Buscar en una lista» practica desplazarse y elegir tres lugares de una
  lista simulada. La consigna permanece visible y el apoyo para revelar un
  elemento se distingue de los gestos manuales (`phone-list-v1`).
- «Ampliar una imagen» practica separar dos dedos y juntarlos para volver al
  tamaño inicial. Guarda gestos logrados, intentos y uso del botón de apoyo
  por separado, con ampliación acotada y una ilustración local (`phone-zoom-v1`).

- Memorice clásico: scoring real para los tres niveles con los rangos publicados.
  El ejemplo de 4 errores, 20 intentos, 180 segundos y 60% de acierto da 55,8.
- Los demás juegos con el contrato de scoring cognitivo envían sus métricas reales, pero el backend responde
  `422 calibration_pending` hasta que se definan sus rangos `mejor`/`peor`.
  Sus métricas se guardan y el score queda pendiente; no se inventan rangos.
- Errores de conexión o configuración dejan el score pendiente, nunca en 70.
- Los resultados nuevos se guardan con `scoringVersion`.
  Los scores antiguos sin esa marca no se consideran resultados reales ni
  entran en tendencias. Sus métricas originales no se eliminan ni se
  recalculan automáticamente.
- La tendencia necesita cinco sesiones analizadas del mismo dominio y nivel en
  28 días. La pantalla de progreso muestra datos reales y estados pendientes.
- Este cambio conserva la persistencia actual en Firestore. La migración a
  almacenamiento local cifrado es una tarea independiente.
- El reintento automático de análisis pendientes y la conexión del dashboard
  del cuidador permanecen fuera de este cambio.

Pruebas del backend (sin llamadas a OpenAI):

```sh
python -m unittest backend.test_scoring -v
```

## Reportes de bienestar — HU-38

`POST /report/generate` recibe solo agregados de los últimos 1 a 28 días.
No consulta Firestore, no guarda reportes ni recibe identidad, UUID, fechas
personales, historial individual o texto libre. Los campos adicionales, tipos
incorrectos y resúmenes inconsistentes se rechazan con `422 invalid_report_data`,
sin reflejar el contenido rechazado en la respuesta.

Ejemplo de request:

```json
{
  "periodo_dias": 28,
  "resumen_dominios": {
    "memoria": {
      "nivel_senal": 2,
      "score_promedio": 68.2,
      "senal": "estable",
      "sesiones": 8
    },
    "praxias": {"senal": "calibracion_pendiente", "sesiones": 3}
  }
}
```

- Dominios permitidos: `memoria`, `atencion`, `praxias`.
- Señales: `estable`, `mejora`, `atencion`, `revisar`, `insuficiente`,
  `calibracion_pendiente`. Las calcula el scoring, no OpenAI.
- Una tendencia requiere al menos cinco sesiones puntuadas del mismo nivel,
  con nivel y puntuación media. No exige esperar 28 días completos.
- Con señal `insuficiente` se permiten puntuaciones reales de menos de cinco
  sesiones, siempre con su nivel. Sin calibración, `score_promedio` se omite
  o es `null`; nunca se sustituye por cero.
- `sesiones` cuenta las sesiones comparables del nivel indicado cuando hay
  scoring; sin scoring cuenta la práctica registrada, sin atribuirle tendencia.
- El endpoint valida el contrato; no puede verificar los agregados contra una
  base de datos. El cliente debe construirlos con resultados reales compatibles.

La respuesta siempre contiene texto para un request válido:

```json
{
  "reporte_texto": "Texto del reporte y aviso médico obligatorio.",
  "generado_con": "plantilla_local",
  "motivo_respaldo": "timeout"
}
```

`generado_con` es `openai` o `plantilla_local`. `motivo_respaldo` es `null`
cuando responde OpenAI; en el respaldo indica `timeout`, `service_error`,
`invalid_response`, `no_data`, `insufficient_data` o `calibration_pending`.
Siempre se añade el aviso médico y el texto queda limitado a 150 palabras.

El plazo total de generación externa es de ocho segundos, sin reintentos
automáticos. Una llamada que vence se cancela; el servidor devuelve una
plantilla con los mismos hechos. También usa la plantilla si el proveedor
falla, no hay clave, la respuesta está vacía, truncada, rechazada, omite un
dominio o incumple las verificaciones de longitud/lenguaje/cifras. Estas
verificaciones no constituyen una validación clínica del texto generado.
Si ningún dominio tiene tendencia disponible, se usa directamente la plantilla
para describir la práctica y explicar qué información falta, sin llamar a IA.

Configurar `OPENAI_API_KEY` en el entorno o `backend/.env`; no incluirla en Git.
`OPENAI_REPORT_MODEL` permite configurar el modelo; por defecto conserva
`gpt-5.6-luna`, utilizado en el spike. La llamada usa `store=false`; eso no
sustituye las políticas de retención del proveedor. No se envían identidad,
cabeceras del cliente ni metadatos del usuario a OpenAI.

Requiere **Python 3.11+**. Para preparar un entorno separado (sin reemplazar
un `backend/venv` anterior), desde la raíz:

```sh
python3.11 -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/requirements.txt
source backend/.venv/bin/activate
```

Pruebas sin red ni consumo de OpenAI:

```sh
python -m unittest backend.test_reports backend.test_scoring -v
```

Las pruebas incluyen el plazo real de ocho segundos, cancelación, disponibilidad
de `/health` durante la espera, inspección del JSON enviado al SDK y rechazo de
identificadores. Para iniciar, usar el comando de Uvicorn indicado arriba.

Esta tarea cubre el backend. Conectar el reporte con Flutter, exportar el PDF
y ofrecer respaldo en el teléfono cuando el servidor no sea accesible son
trabajos independientes. Una plantilla del servidor no cubre la falta de
conexión entre el teléfono y FastAPI.

## Navegación con GoRouter

`core/router/app_router.dart` centraliza el arranque, bienvenida, selección de
rol, registro/login de ambos roles, recuperación de contraseña, disclaimer,
selección de modo y las pantallas de inicio. `AuroraCareApp` usa
`MaterialApp.router`; Riverpod conserva una única instancia del router.

Los destinos están en `app_routes.dart`. Los nombres, correos e identificadores
no forman parte de las URLs. `navigation_policy.dart` decide los redirects
según la sesión restaurada y el onboarding pendiente; los datos desconocidos
por falta de conexión mantienen el comportamiento anterior del arranque.
Login y finalización del onboarding usan `go` para retirar las pantallas de
acceso de la pila. Cerrar sesión limpia el estado de navegación y vuelve a
Bienvenida. Las pantallas conservan callbacks opcionales para pruebas aisladas.

La navegación interna de juegos, respiración y pantallas secundarias sigue
usando Navigator en esta migración; GoRouter permite esa convivencia. El acceso
del cuidador conserva su demostración existente y no acredita autenticación
real ni habilita las rutas privadas del adulto mayor. La navegación de
recuperación está conectada, pero el envío real del correo continúa pendiente
en el módulo de autenticación. Reportes todavía no tiene una pantalla real.

Tras incorporar la dependencia y cambiar a `MaterialApp.router`, reiniciar la
app (hot restart, `R` en la terminal de Flutter) para probar el nuevo arranque.

## Conecta los puntos — experiencia de práctica

La práctica usa la paleta de AuroraCare y números de 48 dp de diámetro.
Se puede levantar el dedo y retomar desde el último trazo o el último punto
unido, pausar, reiniciar la figura y consultar una demostración. El tablero
conserva el progreso al cambiar de tamaño y sus gestos no desplazan la página.
La figura se cierra al volver al punto 1: el juego no dibuja ese tramo por la
persona. Una animación breve precede al diálogo para seguir, repetir o ver el
resumen final; respeta la opción de reducir animaciones.

Las observaciones nuevas usan `connectionVersion: connect-dots-v2`. Guardan
los intentos, figuras, objetivos alcanzados (incluido el regreso al inicio),
precisión por distancia, tiempo activo real, toques fuera de orden, alzadas del
dedo y demostraciones. No se persisten coordenadas ni se asigna una puntuación
cognitiva sin calibración. Sin desplazamiento, la precisión del intento queda
en `null`, no en un porcentaje ficticio.

La precisión principal corresponde al último intento completado de cada figura,
ponderada por la distancia recorrida. El tiempo incluye los intentos repetidos
y excluye pausas, demostraciones y espera entre figuras. Se diferencia del
tiempo normalizado de versiones anteriores: no se recalculan datos antiguos
ni se usan ambas versiones como si fueran la misma medida.


### Reporte desde Mi progreso

El botón abre `/home/report` con los recuentos y las observaciones de la última
partida de cada dominio en los últimos 28 días. Incluye las sesiones sin score:
la falta de calibración no elimina el historial. Las tendencias solo usan las
sesiones analizadas del mismo nivel; sus cantidades se distinguen del total.
No se exige esperar 28 días completos.

La redacción consulta `/report/generate` usando `AURORACARE_API_BASE_URL`. Solo
envía dominios, cantidades, nivel, media y señal; nunca identidad, UUID, fechas
ni sesiones individuales. Sin configuración, ante error o tras 10 segundos de
espera del cliente, muestra una plantilla del dispositivo con los mismos
agregados y el aviso médico. El servidor conserva su límite de 8 segundos.
El reporte se consulta en pantalla; esta tarea no añade exportación PDF.

El historial pertenece a la referencia de perfil conservada en cada dispositivo.
Ver las partidas en el teléfono confirma su disponibilidad allí; no las migra
a otro dispositivo. No se buscan perfiles ajenos ni se reconstruye un UUID
perdido a partir de identidad o semejanzas entre partidas.


### Etapa anterior: cambio de modo con QR simulado

Esta etapa fue reemplazada por la implementacion descrita en «Invitaciones QR reales».

El repositorio de invitaciones sigue siendo una simulación local: no concede
acceso real al cuidador. En esta etapa, pasar de 3 a 2 cancela todas sus
invitaciones persistidas (incluidas usadas o vencidas) y guarda el modo 2 por
transacción en `users/{uid}`. Mantiene el UUID cognitivo y sus sesiones.
Si falla la cancelación o la transacción, no confirma el cambio en pantalla.
Una cancelación ya realizada no se deshace si después falla la conexión.

La transacción guarda `caregiverSharingEnabled: false` y aumenta
`caregiverAccessEpoch` al pasar de 3 a 2. Volver a modo 3 no habilita compartir
ni recupera invitaciones anteriores. Estos campos no contienen métricas ni UUID
cognitivo. Si el servidor ya marca acceso real habilitado, se mantiene el
bloqueo hasta implementar su revocación efectiva.

**Límite:** esto habilita el cambio seguro para la simulación actual, no es
una implementación de vinculación/desvinculación real. Las reglas documentadas
mantienen `caregiver_links` y `caregiver_invites` bloqueadas. Antes de habilitar
F8 real, el canje QR y cada lectura del cuidador deben comprobar en el servidor
el consentimiento vigente y la generación del permiso; el cambio a modo 2 debe
revocar ese acceso atómicamente. Un campo por sí solo no protege las lecturas.
No se desplegaron reglas ni cambios de servidor en esta tarea.


## Reglas de Firestore versionadas

`firestore.rules` conserva las reglas facilitadas por el equipo y añade los
campos `caregiverSharingEnabled` y `caregiverAccessEpoch` a la identidad básica.
La simulación solo puede guardar compartir desactivado; la generación aumenta
exactamente en uno al pasar de modo 3 a 2 y se conserva en otros cambios.
Admite documentos anteriores sin estos campos y mantiene los bloqueos de F8.
No cambia las reglas de acceso a perfiles cognitivos ni sesiones.

Sin esta actualización, la lista cerrada de campos de `users/{uid}` rechaza
la transacción de cambio de modo con `permission-denied`. Cambiar el código
local no actualiza las reglas publicadas: es necesario publicar el archivo
completo en Firebase Console → Firestore Database → Reglas, seleccionando
el proyecto `duocauroracare`. No se publican automáticamente al ejecutar Flutter.

Pruebas de reglas con datos ficticios en un proyecto de emulador `demo-*`
(requieren Node y Java compatibles con las versiones fijadas en el paquete):

```sh
npm --prefix test/firestore install
npm --prefix test/firestore test
```

Las pruebas comprueban el payload del cambio de modo, ciclos y reintentos,
propiedad de la cuenta, preservación de consentimiento, rechazo de generaciones
inválidas, separación de identidad y métricas y bloqueo de vínculos reales.


## Aislamiento local del historial por cuenta

Cada cuenta autenticada conserva una referencia de perfil propia en el
dispositivo. La referencia se guarda como un único registro JSON versionado,
antes de escribir en Firestore, para no perder el UUID si falla la red.
Cambiar de modo conserva esa referencia. Cerrar sesión no borra las partidas;
al volver a entrar en la misma cuenta se recupera su perfil.

La asociación cuenta-perfil solo se guarda localmente: no se añade identidad
ni una referencia al UUID cognitivo a `users/{uid}` ni identidad a las métricas.
Los repositorios rechazan leer o escribir sesiones de un perfil que no sea el
de la cuenta actual y descartan respuestas recibidas después de cambiarla.
La creación concurrente comparte una referencia; un registro dañado no genera
un UUID nuevo silenciosamente.

Las claves globales antiguas se conservan sin reasignarlas automáticamente.
El progreso muestra un aviso y el reporte indica que ese historial pendiente
de asociación no se incluye. Recuperarlo requiere comprobar su titular;
ni iniciar sesión ni cambiar de modo constituye esa comprobación.

Alcance: aislamiento de la aplicación en este dispositivo, no cifrado del
almacenamiento ni autorización de Firestore. Las reglas actuales todavía
permiten acceso a una ruta cognitiva conocida por un usuario autenticado.
La revisión de permisos del servidor y el respaldo/cambio de teléfono siguen
pendientes; no se deben presentar como resueltos por este cambio local.


## Autenticación real de cuidador

El registro y acceso del cuidador usan Firebase Auth y un documento de identidad
en `users/{uid}` con `role: caregiver`, nombre, fecha de creación y modo 0.
No crean perfiles cognitivos, no incluyen UUID cognitivos y no asocian personas
con métricas. La selección de rol organiza la interfaz y no concede permisos
sobre sesiones ajenas. Los documentos anteriores sin rol se consideran de
adulto mayor; una cuenta no cambia de rol mediante actualización del cliente.

El acceso comprueba el rol en el servidor antes de abrir el panel. El cierre
de sesión llama a Firebase Auth. Al reabrir se restaura la pantalla según
el rol; sin red solo se utiliza el rol previamente conocido de la misma
cuenta. Si el rol no se conoce, se solicita elegir el acceso y volver a
autenticarse. La caché local de rol contiene identidad de navegación, sin
referencias ni métricas cognitivas.

Si falla el documento de un registro nuevo se intenta retirar ese documento
y eliminar exclusivamente la cuenta recién creada. Si la limpieza también
falla se informa que el registro no se completó, sin abrir el panel.

Antes de probar registro real hay que publicar la actualización de
`firestore.rules`, que admite el campo de identidad `role`, valida sus valores
y evita modificarlo posteriormente. Este cambio no despliega reglas.
El canje QR real se describe en F8. Los resúmenes remotos del cuidador siguen
pendientes; el escáner solo confirma vínculos aceptados por Firestore y no
se muestran notificaciones de ejemplo. No se modifica la separación entre identidad y
métricas ni se añade la asociación remota descartada por el equipo.

## Invitaciones QR reales (F8)

El adulto mayor y el cuidador usan el mismo formato:
`auroracare://caregiver-invite/v1/{token}`. El token contiene 32 bytes aleatorios
generados con `Random.secure`, sin datos personales ni UUID cognitivos.
Los códigos simulados anteriores no son canjeables. El proveedor principal usa
`FirestoreCaregiverInviteRepository`; el fake queda reservado a pruebas.

`caregiver_invites/{token}` conserva el UID de quien lo generó, `createdAt`
fijado por el servidor, duración fija de 600 segundos, generación de permiso,
versión del consentimiento y estado. El vencimiento es `createdAt + 600 s`,
no una fecha elegida por el teléfono. Las reglas comparan con `request.time`;
la cuenta regresiva local solo sirve de presentación.

El canje comprueba la cuenta de cuidador y crea, en una transacción, el
comprobante de uso y `caregiver_links/{token}` con los UID de ambas cuentas.
Los punteros privados `caregiver_invite_state/{adultUID}` y
`caregiver_link_state/{caregiverUID}` permiten restaurar el estado sin listar
invitaciones ni vínculos. El cuidador muestra la última vinculación elegida;
no se implementa todavía un selector de varias personas.

La invitación solo se consume una vez. Generar otra retira la invitación y
vinculación previas (se informa antes de aceptar); cancelar o desvincular
invalida el código y revoca el vínculo. Pasar al modo personal exige retirar
primero el puntero: las reglas también rechazan omitir ese paso. La app hace
la retirada antes de guardar el modo: si el segundo paso falla, no reactiva
el vínculo anterior ni borra partidas.

Privacidad y alcance: los vínculos relacionan cuentas entre sí, nunca cuentas
con perfiles cognitivos. No contienen nombres, correos, respuestas, sesiones
ni UUID cognitivos. Este canje no habilita leer partidas completas ni crea
el resumen compartido: ambas pantallas lo indican sin datos ficticios. Las
reglas de lectura de métricas conservan el diseño y el riesgo aceptado por el
equipo; se amplía la validación para rechazar campos de identidad como
`adultUID` y `caregiverUID` dentro de los datos cognitivos.

Antes de probar con dos dispositivos hay que publicar el archivo actualizado
`firestore.rules` completo y reiniciar Flutter. No se despliega al hacer push.
El proyecto de emulador `demo-auroracare-rules` y las pruebas de
`test/firestore/` validan el canje sin tocar cuentas reales.
