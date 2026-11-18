#!/bin/sh
# Prueba de humo compartida por Jenkins y GitHub Actions.
#
# Uso: sh scripts/prueba_humo.sh <imagen> <nombre-contenedor>
#
# 1. Arranca la imagen recién construida en segundo plano.
# 2. Consulta GET /salud dentro del contenedor, con reintentos, hasta que
#    responda HTTP 200 con un JSON que contenga "estado": "ok".
# 3. Falla si no lo logra dentro del límite de tiempo (HUMO_TIMEOUT, en s).
#
# La eliminación del contenedor NO se hace aquí: la garantiza cada pipeline
# en su bloque post/always (Jenkins) o en un paso con if: always() (Actions).
set -eu

IMAGEN="${1:?Indica la imagen a probar}"
CONTENEDOR="${2:?Indica el nombre del contenedor}"
LIMITE="${HUMO_TIMEOUT:-30}"   # segundos máximos de espera
PAUSA="${HUMO_PAUSA:-2}"       # segundos entre intentos

# Validación ejecutada con el Python de la propia imagen (sin dependencias).
VALIDADOR='
import json, sys, urllib.request
with urllib.request.urlopen("http://localhost:8000/salud", timeout=3) as r:
    codigo, cuerpo = r.status, r.read().decode("utf-8")
if codigo != 200:
    sys.exit(f"HTTP {codigo} inesperado: {cuerpo}")
if json.loads(cuerpo).get("estado") != "ok":
    sys.exit(f"Respuesta sin estado ok: {cuerpo}")
print(f"HTTP {codigo} {cuerpo}")
'

docker run -d --name "$CONTENEDOR" "$IMAGEN" >/dev/null
echo "Contenedor $CONTENEDOR iniciado desde $IMAGEN; esperando /salud (máx. ${LIMITE}s)"

inicio=$(date +%s)
intento=1
while :; do
  if respuesta=$(docker exec "$CONTENEDOR" python -c "$VALIDADOR" 2>&1); then
    echo "Prueba de humo superada en el intento $intento: $respuesta"
    exit 0
  fi
  if [ $(( $(date +%s) - inicio )) -ge "$LIMITE" ]; then
    echo "Prueba de humo FALLIDA tras ${LIMITE}s y $intento intentos." >&2
    echo "Último error: $respuesta" >&2
    echo "--- Registro del contenedor ---" >&2
    docker logs "$CONTENEDOR" >&2 || true
    exit 1
  fi
  intento=$((intento + 1))
  sleep "$PAUSA"
done
