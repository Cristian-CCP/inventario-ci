# inventario-ci

Aplicación mínima de inventario en Python usada en el ejercicio **“Un pipeline, dos motores: Jenkins + Docker y GitHub Actions”** (Integración Continua · Unidad 2 / Escenario 4).

El mismo flujo de integración continua se implementa en dos motores:

| Etapa | Jenkins (`Jenkinsfile`) | GitHub Actions (`.github/workflows/ci.yml`) |
|---|---|---|
| Pruebas unitarias en contenedor efímero `python:3.12-slim` + reporte JUnit `reportes/pruebas.xml` | `Pruebas unitarias` | job `pruebas` (artefacto `reporte-pruebas`) |
| Construcción de la imagen (solo si las pruebas pasan) | `Construir imagen` | job `imagen` → paso `Construir imagen` |
| Prueba de humo: `GET /salud` → HTTP 200 y `"estado": "ok"`, con reintentos (máx. 30 s) | `Prueba de humo` | job `imagen` → paso `Prueba de humo` |
| Limpieza garantizada del contenedor temporal | `post { always }` | paso con `if: always()` |

## Estructura

```
src/inventario/        código de la aplicación (core.py, api.py)
tests/                 pruebas unitarias (pytest, 7 casos)
scripts/prueba_humo.sh prueba de humo compartida por ambos pipelines
Dockerfile             imagen de ejecución (usuario sin privilegios + HEALTHCHECK)
Jenkinsfile            pipeline declarativo de Jenkins
.github/workflows/ci.yml  pipeline de GitHub Actions
```

## Ejecución local

```bash
# Pruebas en un contenedor efímero
docker run --rm -v "$PWD":/app -w /app python:3.12-slim \
  sh -c "pip install -q -r requirements-dev.txt && mkdir -p reportes && pytest --junitxml=reportes/pruebas.xml"

# Imagen + prueba de humo
docker build -t inventario:local .
sh scripts/prueba_humo.sh inventario:local humo-local; docker rm -f humo-local
```

## API

- `GET /salud` → `{"estado": "ok", "version": "1.0.0"}`
- `GET /inventario` → productos de ejemplo y valor total
