FROM maven:3.8.2-openjdk-16-slim AS builder
ARG VERSION=${VERSION}
WORKDIR /usr/src/app
COPY ./src ./src
COPY *.xml ./

RUN mvn -B package -Dversion.application=${VERSION}

FROM eclipse-temurin:16-jdk-alpine
ARG VERSION=${VERSION}
WORKDIR /app

RUN apk upgrade --no-cache \
    && apk add --no-cache dumb-init \
    && addgroup -S -g 1001 jaruser \
    && adduser -S -s /sbin/nologin -G jaruser -u 1001 -D -H jaruser \
    && mkdir -p /logs/reports \
    && chown -R jaruser:jaruser /logs
COPY --chown=jaruser:jaruser \
     --from=builder /usr/src/app/target/sausage-store-${VERSION}.jar ./sausage-store.jar
EXPOSE 8080

USER 1001:1001

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/actuator/health >/dev/null || exit 1

ENTRYPOINT ["dumb-init", "java", \
  "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-Dmyserver.bindPort=8080", \
  "-jar", "/app/sausage-store.jar"]
