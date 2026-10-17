# Tamagit — Decisiones de diseño

> Resultado de la entrevista de diseño del 2026-10-16. Cada decisión lleva su porqué.
> Los números (umbrales, topes, bonificaciones) son **valores iniciales**: viven como
> constantes con nombre en `tamagit-core` y se ajustan con pruebas.

## 1. Qué es y qué no es

Tamagit es un perezoso costarricense que vive en la terminal y se alimenta del trabajo real:
commits (comida), pruebas (salud), descansos (energía) y atención (ánimo). Dos piezas:

- **Cliente** (`tamagit`): CLI + pantalla interactiva animada, estado local, hook de Git.
- **Servidor** (Spring Boot): sincronización entre computadoras, insignia SVG, `visit` y ranking.

**Principio rector:** lo más simple que funcione. Ante la duda, se recorta.

**Fuera de alcance (v1):** chat, compras, cuentas con contraseña, notificaciones de escritorio,
procesos en segundo plano, Windows, más especies, integración con Pinghouse, Homebrew, firma de binarios de macOS.

## 2. Estructura y tecnología

| Decisión | Porqué |
|---|---|
| **Monorepo Maven multi-módulo**: `tamagit-core`, `tamagit-cli`, `tamagit-server` | Las reglas del juego se escriben una sola vez (en `core`) y las usan cliente y servidor; un solo CI y un solo README. |
| `core` **sin dependencias** (ni Spring, ni Picocli, ni Jackson) | Pruebas con JUnit puro y rápidas; ninguna reflexión que moleste a GraalVM. |
| **Java 25 LTS + Maven** | LTS vigente; GraalVM 25 y AOT cache de Leyden como plan B de arranque. Maven ya está instalado. |
| Cliente: **Picocli + JLine 4 + dibujo ANSI propio + Jackson** | JLine resuelve el modo crudo, el tamaño y las teclas; el dibujo lo controlamos nosotros. Lanterna es más de lo necesario. JLine 4 (y no 3) porque es la línea activa, usa FFM para la terminal y no hace falta compatibilidad con Java 8; si no compila como native image en H1-05, el plan B es JLine 3. |
| Servidor: **Spring Boot (Web, Data JPA, Security, Validation, Actuator) + Flyway + PostgreSQL** | Es tu stack y tu despliegue común. SQLite alcanzaría por volumen, pero PostgreSQL te sirve para practicar el despliegue compartido. |
| Pruebas: JUnit 5 en todo; **Testcontainers solo en `server`** | `core` es puro; `cli` se prueba con Picocli y un directorio temporal. |
| Coordenadas: `io.github.sharltonrb`, paquete `io.github.sharltonrb.tamagit.{core,cli,server}` | Vinculadas a la cuenta de GitHub `SharltonRB`. |
| Repo **público**, licencia **MIT** | Es un portafolio; además los runners ARM y macOS de GitHub son gratuitos en repos públicos. |

Las versiones exactas (Spring Boot, GraalVM, JLine, Picocli, Jackson) se verifican contra las fuentes oficiales en el arranque, no se fijan de memoria.

## 3. Modelo de dominio (`tamagit-core`)

### 3.1 Eventos como fuente de verdad

- La verdad es un **libro de eventos** que solo crece; nunca se editan ni se borran eventos.
- `estado = proyectar(eventos, ahora)` es una **función pura**. El reloj se inyecta (`java.time.Clock`).
- Tipos: `COMMIT`, `TESTS_PASSED`, `TESTS_FAILED`, `PET`, `REST_STARTED`, `REST_ENDED`.
- Cada evento tiene un `id` (UUID aleatorio), `type` y `occurredAt`.
- El paso del tiempo **no** genera eventos: se calcula al proyectar.

### 3.2 Barras («más es mejor»)

**Comida, Ánimo, Salud y Energía**, de 0 a 100. Energía usa **6 pilas**.

| Fuente | Comida | Ánimo | Salud | Energía | Tope |
|---|---|---|---|---|---|
| `COMMIT` | +15 | +2 | — | −1 pila | 4/hora cuentan para comida |
| `TESTS_PASSED` | — | +5 | +20 | — | 3/hora |
| `TESTS_FAILED` | — | — | −15 | — | — |
| `PET` | — | +10 | — | — | 5/día; no cuenta para el ranking |
| Descanso completo | — | +5 | — | pilas llenas | — |
| Cada hora sin atención | −4 | −2 | — | — | el decaimiento se detiene tras 48 h |

- **La comida solo viene de commits.** No existe la alimentación manual.
- **La salud depende solo de las pruebas** y se queda neutra si nunca se ejecutan. Por debajo de 30 se muestra el dibujo de «enferma».

### 3.3 Energía y descanso

- Cada commit gasta 1 pila. Con 0 pilas: dibujo agotado, la línea del hook sugiere `tamagit rest`, y
  si se ignora, cada commit baja el ánimo.
- `tamagit rest` → `REST_STARTED` (dibujo en la hamaca). `tamagit wake` o una tecla en la pantalla interactiva → `REST_ENDED`.
  - Dormido ≥ 15 min: pilas llenas y un poco de ánimo.
  - Dormido < 15 min: recupera solo una parte y se despierta de mal humor.
- Los commits hechos mientras duerme guardan la comida; se la come al despertar.
- Una pausa de ≥ 8 h sin eventos llena las pilas automáticamente (la noche cuenta como descanso).
- La pregunta «¿Tomamos un descanso?» aparece **solo** en la pantalla interactiva o en `status`; el hook nunca pregunta nada.

### 3.4 Racha, evolución y ausencia

- **Día activo** = un día con al menos un `COMMIT`, en la **zona horaria del perfil** (por ejemplo `America/Costa_Rica`), no en la de cada máquina.
- **Racha** = días activos seguidos, con **un comodín por cada 7 días** (se puede saltar un día sin perderla).
- **Evolución por días activos**: Cría (0) → Joven (7) → Adulto (30). **La etapa nunca retrocede.**
- **No muere.** Si la abandonas, las barras bajan hasta un piso; tras **3 días** sin eventos entra en
  **hibernación** (dibujo propio). El primer commit la despierta con hambre, y se recupera con unos pocos commits.

## 4. Cliente (`tamagit-cli`)

### 4.1 Comandos

| Comando | Qué hace |
|---|---|
| `tamagit` | Pantalla interactiva animada. La primera vez, hace nacer a la mascota. |
| `tamagit status` | Estado en texto (barras, etapa, racha, sugerencias). |
| `tamagit pet` | Acaricia a la mascota (`PET`). |
| `tamagit rest` / `tamagit wake` | Empieza y termina el descanso. |
| `tamagit test -- <cmd>` | Ejecuta tus pruebas y registra `TESTS_PASSED` o `TESTS_FAILED` según el código de salida. |
| `tamagit install-hooks` / `uninstall-hooks` | Instala o quita el bloque del hook en el repo actual. |
| `tamagit login` | Login con GitHub (Device Flow). Opcional. |
| `tamagit sync` | Push y pull de eventos. |
| `tamagit profile --public / --private` | Visibilidad en el ranking y en `visit`. |
| `tamagit visit <usuario>` | Muestra la mascota pública de otro usuario. |

El comando `feed --source …` del borrador **desaparece**: la comida entra por el buzón.

### 4.2 Archivos locales (`~/.tamagit/`)

- `events.jsonl`: el libro de eventos local, un evento por línea. Los `COMMIT` guardan aquí el SHA **solo en local**, para no contar dos veces el mismo commit.
- `inbox`: el buzón que escribe el hook (una línea `<sha> <epoch>` por commit).
- `state.json`: solo una caché de la última proyección, para que `status` sea instantáneo. Se puede borrar y regenerar.
- `config.json`: URL del servidor, cursor de sincronización, preferencias (por ejemplo, desactivar la línea del hook).
- `credentials`: el token de dispositivo, con permisos `600`. *(Supuesto; se confirma en H5.)*

Todo comando procesa primero el buzón: lo convierte en eventos y lo vacía. Dos procesos `tamagit` a la vez son posibles, así que hace falta un bloqueo de archivo (se resuelve en H3).

### 4.3 Hook de Git

- **Buzón**: el hook es shell puro, no ejecuta Java. Agrega una línea a `~/.tamagit/inbox` e imprime
  una reacción fija (`🦥 ñam (+1 commit)`), que se puede desactivar. Esto garantiza que el commit no se ralentiza (≈1 ms), aunque native image falle.
- **Se instala por repo**, como un bloque marcado `# >>> tamagit >>>` … `# <<< tamagit <<<` agregado al
  `post-commit` existente. **Nunca** se sobrescribe un hook ni se usa `core.hooksPath` global, porque rompería husky o pre-commit.
- Si tamagit se desinstala, el hook no rompe los commits.
- `rebase`, `amend` y `cherry-pick` generan SHAs nuevos; el tope de 4 commits por hora evita que sobrealimenten.

### 4.4 Pantalla y arte

- Pantalla alterna, cursor oculto, el cuadro completo armado en un `StringBuilder` y escrito de una sola vez: así no hay parpadeo.
- **Una especie: perezoso de tres dedos** colgando de un guarumo, que come hojas de guarumo.
- 3 etapas × 2 cuadros = **6 dibujos base**, más **capas por estado** (ojos, boca, `zZz`, gotas, termómetro, hamaca).
- ASCII + caracteres de dibujo de cajas + color ANSI; **sin emoji dentro del dibujo** (su ancho varía según la terminal). Barras en los colores de la bandera.
- Textos en español con jerga tica moderada («¡Pura vida, mae!»), todos en un archivo de mensajes.
- El borrador del arte (`resources/art/`) lo hace Claude; lo pule Sharlton.

### 4.5 Primer uso (meta: < 2 min)

1. `curl -fsSL <url>/install.sh | sh`
2. `tamagit` → «¡Encontraste un perezoso en un guarumo! ¿Cómo se llama? [Chepe]», zona horaria detectada, y si estás dentro de un repo, la oferta de instalar el hook.
3. El login es opcional; `status` lo sugiere una sola vez.

## 5. Servidor (`tamagit-server`)

### 5.1 Identidad: GitHub Device Flow

- El **cliente** hace el Device Flow con el `client_id` público de una GitHub OAuth App.
- El cliente envía el token de GitHub **una sola vez** al servidor. El servidor llama a `api.github.com/user`, descarta ese token y
  emite **su propio token de dispositivo**, del que guarda **solo el hash**.
- Cada computadora hace su propio login. Sin contraseñas, sin correo, con el nombre de usuario verificado.

### 5.2 Sincronización

- **Push**: `POST /api/v1/events` con un lote de eventos. La inserción es idempotente por `id`: un id repetido se ignora.
- **Pull**: `GET /api/v1/events?after=<cursor>`, donde el cursor es `seq` (bigserial).
- Como los eventos solo se agregan, **no se pierden alimentaciones**, y en los eventos no hace falta bloqueo optimista.
- **`@Version` (bloqueo optimista) solo en el perfil** (nombre, zona horaria, visibilidad), que es lo único que se edita.
- El servidor **valida**: tipo conocido, `occurredAt` no más de 5 min en el futuro ni más de 30 días en el pasado, y tamaño máximo del lote.
  El ranking usa **la proyección del servidor**, nunca valores que envíe el cliente.

### 5.3 Privacidad

Al servidor solo viaja `{id, type, occurredAt}`. **Nunca** se envían el SHA, el repositorio, la rama ni el mensaje del commit.
Lo que se acepta a cambio: el servidor no puede verificar que un commit existió (se mitiga con los topes), y `occurredAt` revela el horario de trabajo (es el dato mínimo que necesitan la racha y la energía).

### 5.4 Datos (Flyway)

```
pet          id, github_id (único), github_login, name, timezone,
             is_public, version, created_at
device_token id, pet_id, token_hash (único), created_at, last_used_at, revoked_at
event        id (UUID del cliente, PK), pet_id, type, occurred_at, received_at, seq (bigserial)
pet_stats    pet_id (PK), streak, active_days, stage, updated_at
```

`pet_stats` es una **proyección guardada** (CQRS mínimo): se recalcula con `core` después de cada push y se puede regenerar a partir de `event`.
Hay **una mascota por usuario**.

### 5.5 Endpoints públicos

- `GET /badge/{githubLogin}.svg`: plantilla de texto, **XML escapado**, nombre limitado (~20 caracteres de un conjunto permitido),
  `Cache-Control: max-age=300` (GitHub cachea las imágenes en *camo*). Un perfil privado o inexistente recibe una insignia genérica, no un error.
- `GET /api/v1/visit/{githubLogin}` y `GET /api/v1/leaderboard?by=streak|stage`: solo perfiles públicos (público por defecto; se pregunta en el login).
- `GET /actuator/health`.

### 5.6 Protección

- **Bucket4j en memoria**: ~30 peticiones/min por token (sincronización) y ~60/min por IP (endpoints públicos). Basta porque hay una sola instancia.
- Logs **JSON** con el *structured logging* nativo de Spring Boot (sin configurar Logback).

## 6. Distribución y despliegue

- **Plataformas v1**: macOS arm64 y Linux x64 (y Linux arm64 si sale gratis en la matriz). Windows en la v2.
- **Cliente**: GraalVM native image → GitHub Releases → `install.sh` (detecta el sistema y la arquitectura, instala en `~/.local/bin`). Sin firma de Apple:
  el README explica `xattr -d com.apple.quarantine` para quien descargue el binario a mano.
- **Plan B**, si native image no sale en ~2 días de trabajo en H1: un `.tar.gz` con un runtime recortado por jlink + AOT cache de Java 25. No pide Java instalado.
- **Servidor**: imagen arm64 construida en un runner ARM de GitHub Actions → GHCR (`ghcr.io/sharltonrb/tamagit-server`) →
  en la VM de Oracle, `docker compose pull && up -d`, junto al PostgreSQL compartido (base `tamagit`) y detrás de Caddy (HTTPS).
  Los secretos van en un `.env` en la VM, nunca en el repo. Plan B: Render + Neon.
- **Dominio**: pendiente. Recomendado: un subdominio `tamagit.<dominio>` en Cloudflare. En el código va como `TAMAGIT_PUBLIC_URL`.
- **CI**: `mvn verify` en cada push/PR; una matriz de native image para mac y linux; un workflow de release al crear un tag `v*`.

## 7. Hitos

| Hito | Contenido | Quién |
|---|---|---|
| **H0** | Arranque: monorepo, poms, estructura de paquetes, Dockerfile multi-etapa, compose, CI, `.gitignore`, esqueleto del README, `git init` y 4–5 commits pequeños | Claude |
| **H1** | Prueba de native image: `tamagit hello` (Picocli + JLine + Jackson) compilado como native en el CI para mac y linux | Sharlton |
| **H2** | `core`: eventos, proyección, tabla de efectos, energía, racha, evolución, hibernación | Sharlton |
| **H3** | `cli`: `status`, `pet`, `rest`/`wake`, `test`, buzón, `install-hooks` | Sharlton |
| **H4** | Pantalla interactiva con animación y arte → **mínimo usable** | Sharlton (arte: borrador de Claude) |
| **H5** | Servidor: login con GitHub, push/pull de eventos, `pet_stats` (Testcontainers) | Sharlton |
| **H6** | Insignia SVG + despliegue en Oracle | Sharlton |
| **H7** | `visit` + ranking | Sharlton |
| **H8** | Releases + `install.sh` | Sharlton |

No se pasa al siguiente hito sin que Sharlton lo pida. Al terminar cada hito: revisión de código estilo compañero senior.

## 8. Criterios de terminado

- Instalación y primer uso en **< 2 min**.
- El hook agrega **< 300 ms** al commit. Con el buzón, el objetivo real es ≈ 1 ms, sin depender de native image.
- **Sincronizar desde dos computadoras no pierde alimentaciones**: lo demuestra una prueba de integración que simula dos dispositivos.

## 9. Preferencias de ingeniería que no aplican igual

- **Logs JSON**: solo en el servidor. La CLI no escribe logs en la terminal; como mucho, `~/.tamagit/debug.log` con `--verbose`.
- **Testcontainers**: solo en `server`.
- **Actuator `/actuator/health`**: solo en `server`.

## 10. Abierto o por decidir más adelante

- Dominio definitivo (§6).
- Números finos de la tabla de efectos (se ajustan en H2 con pruebas).
- Dónde se guarda el token en el cliente (§4.2, supuesto: archivo con permisos `600`).
- Cómo marca el cliente qué eventos faltan por enviar (H5).
- v2: Windows, rana de ojos rojos y jaguar, Homebrew, energía según la hora del día, recordatorio vía launchd/systemd, Pinghouse.

## 11. Acuerdo de trabajo

Sharlton programa la lógica (servicios, controladores, consultas, algoritmos y sus pruebas). Claude guía: explica conceptos,
propone rutas de investigación, hace preguntas de diseño, revisa el código y da pistas al depurar. Claude puede hacer el arranque (H0) y el
borrador del arte. Si Sharlton dice «dame el código», Claude le recuerda este acuerdo y pregunta si es una excepción puntual.
