# Versiones verificadas

> Verificadas el **2026-10-17** contra las fuentes oficiales (no de memoria).
> "Publicada" es la fecha del artefacto en Maven Central o de la release oficial.
> Cuando una versión cambie, se actualiza aquí y en las `<properties>` del `pom.xml` padre.

## Plataforma

| Herramienta | Versión | Publicada | Fuente |
|---|---|---|---|
| Java (Temurin) | 25.0.4.1+1 (LTS) | 2026-08-18 | https://api.adoptium.net/v3/assets/latest/25/hotspot |
| Maven | 3.10.0 | 2026-09-27 | https://repo1.maven.org/maven2/org/apache/maven/apache-maven/ |
| GraalVM CE (Java 25) | 25.4.4.1.1 (`graal-25.4.4.1.1`) | 2026-09-22 | https://github.com/graalvm/graalvm-ce-builds/releases |

- Maven 4.0.0 sigue en *release candidate* (`4.0.0-rc-7`), así que se usa la 3.10.0, la última estable. El wrapper (`./mvnw`) la fija y el enforcer exige ≥ 3.10.0.
- GraalVM no se instala hasta H1.

## Librerías

| Librería | Coordenadas | Versión | Publicada | Fuente |
|---|---|---|---|---|
| Spring Boot | `org.springframework.boot:spring-boot-dependencies` | 4.1.1 | 2026-08-20 | https://spring.io/projects/spring-boot (marcada `current` en https://api.spring.io/projects/spring-boot/releases) |
| JUnit | `org.junit:junit-bom` | 6.1.3 | 2026-08-07 | https://repo1.maven.org/maven2/org/junit/junit-bom/ |
| Picocli | `info.picocli:picocli` | 4.7.7 | 2025-04-19 | https://repo1.maven.org/maven2/info/picocli/picocli/ |
| JLine 3 | `org.jline:jline` | 3.30.17 | 2026-09-08 | https://repo1.maven.org/maven2/org/jline/jline/ |
| Jackson 3 | `tools.jackson:jackson-bom` | 3.2.3 (Boot gestiona 3.1.5) | 2026-09-22 (3.1.5: 2026-07-08) | https://repo1.maven.org/maven2/tools/jackson/jackson-bom/ |
| Jackson 2 | `com.fasterxml.jackson:jackson-bom` | 2.22.3 (Boot gestiona 2.21.5) | 2026-09-21 (2.21.5: 2026-07-07) | https://repo1.maven.org/maven2/com/fasterxml/jackson/jackson-bom/ |
| Flyway | `org.flywaydb:flyway-core` | 13.10.3 (Boot gestiona 12.4.0) | 2026-10-15 (12.4.0: 2026-04-14) | https://repo1.maven.org/maven2/org/flywaydb/flyway-core/ |
| Testcontainers | `org.testcontainers:testcontainers-postgresql` | 2.0.5 (= la que gestiona Boot) | 2026-04-20 | https://repo1.maven.org/maven2/org/testcontainers/testcontainers-postgresql/ |
| Bucket4j | `com.bucket4j:bucket4j_jdk17-core` | 8.21.0 | 2026-10-02 | https://repo1.maven.org/maven2/com/bucket4j/bucket4j_jdk17-core/ |
| GraalVM Native Build Tools | `org.graalvm.buildtools:native-maven-plugin` | 1.1.14 | 2026-09-18 | https://repo1.maven.org/maven2/org/graalvm/buildtools/native-maven-plugin/ |

## Plugins de Maven

| Plugin | Versión | Publicada | Fuente |
|---|---|---|---|
| `maven-compiler-plugin` | 3.16.0 | 2026-08-30 | https://repo1.maven.org/maven2/org/apache/maven/plugins/maven-compiler-plugin/ |
| `maven-surefire-plugin` | 3.6.0 | 2026-08-31 | https://repo1.maven.org/maven2/org/apache/maven/plugins/maven-surefire-plugin/ |
| `maven-failsafe-plugin` | 3.6.0 | 2026-08-31 | https://repo1.maven.org/maven2/org/apache/maven/plugins/maven-failsafe-plugin/ |
| `maven-enforcer-plugin` | 3.6.3 | 2026-05-15 | https://repo1.maven.org/maven2/org/apache/maven/plugins/maven-enforcer-plugin/ |
| `maven-wrapper-plugin` | 3.3.4 | 2025-09-08 | https://repo1.maven.org/maven2/org/apache/maven/plugins/maven-wrapper-plugin/ |

## Notas para los siguientes hitos

- **Jackson: generación 3.** Spring Boot 4.1.1 usa Jackson 3 (paquetes `tools.jackson`) por defecto y gestiona Jackson 2 solo por compatibilidad.
  Como el POM padre importa el BOM de Boot, `cli` y `server` usan la misma versión de Jackson 3 (3.1.5). Las anotaciones siguen en
  `com.fasterxml.jackson.core:jackson-annotations`.
- **Versiones que gestiona Boot.** En `server`, Flyway (12.4.0), Testcontainers (2.0.5) y PostgreSQL JDBC (42.7.13) se toman del BOM de Boot, aunque haya versiones más nuevas sueltas, para que todo sea coherente.
- **JUnit.** El BOM de JUnit se importa antes que el de Boot, así que todos los módulos usan JUnit 6.1.3 (Boot trae 6.0.3).
- **Decisión pendiente para H1: JLine 3 o JLine 4.** `decisiones.md` dice JLine 3 (última: 3.30.17), pero ya existe JLine 4 (4.4.8, 2026-10-11). Hay que elegir en H1, probando cuál compila bien como native image.
- Picocli, JLine, Bucket4j y el plugin de native image se declaran en `<properties>` cuando un módulo los use (H0-04 / H1).
