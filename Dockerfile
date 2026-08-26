# ===== Stage 1: Build Keycloak =====
# Pré-compila as extensões e configurações do Keycloak (Quarkus build).
# Resultado: startup 3x mais rápido e sem recompilação em produção.
FROM quay.io/keycloak/keycloak:26.7.2 AS builder

ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_HTTP_ENABLED=true

RUN /opt/keycloak/bin/kc.sh build

# ===== Stage 2: Runtime =====
# Imagem final com o Keycloak pré-compilado.
# O flag --optimized pula a etapa de build no startup.
FROM quay.io/keycloak/keycloak:26.7.2

COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized"]
