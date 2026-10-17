# syntax=docker/dockerfile:1
# Imagen de tamagit-server. Tags verificados en docs/versiones.md (ambos tienen linux/arm64).

# ---- Etapa build: compila el jar del servidor ----
FROM maven:3.10.0-eclipse-temurin-25-resolute AS build
WORKDIR /build

# Primero solo los pom.xml: la capa de dependencias se reutiliza mientras no cambien.
# Los módulos propios se excluyen porque aún no están compilados ni publicados.
COPY pom.xml .
COPY tamagit-core/pom.xml tamagit-core/
COPY tamagit-cli/pom.xml tamagit-cli/
COPY tamagit-server/pom.xml tamagit-server/
RUN mvn -B -q dependency:go-offline -DexcludeGroupIds=io.github.sharltonrb

# Después el código (cli no hace falta para el servidor)
COPY tamagit-core/src tamagit-core/src
COPY tamagit-server/src tamagit-server/src
RUN mvn -B -pl tamagit-server -am -DskipTests package

# ---- Etapa final: solo la JRE y el jar ----
FROM eclipse-temurin:25.0.4.1_1-jre-resolute

# La imagen JRE no trae curl ni wget, y el HEALTHCHECK lo necesita
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

RUN adduser --system --group --no-create-home tamagit

WORKDIR /app
# El jar queda de root (solo lectura para la app)
COPY --from=build /build/tamagit-server/target/tamagit-server-*.jar /app/app.jar

USER tamagit
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -fsS http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
