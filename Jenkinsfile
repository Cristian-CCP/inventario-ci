// =============================================================
// Pipeline declarativo — Curso Integración Continua · U2 / E4
// Etapas: pruebas dentro de un contenedor -> imagen Docker -> prueba de humo
// Si una etapa falla, las siguientes no se ejecutan.
// =============================================================
pipeline {
  agent none
  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 15, unit: 'MINUTES')
  }
  environment {
    IMAGEN     = "inventario:${env.BUILD_NUMBER}"
    CONTENEDOR = "humo-${env.BUILD_NUMBER}"
  }
  stages {
    stage('Pruebas unitarias') {
      // Jenkins crea un contenedor efímero solo para esta etapa y lo elimina al final
      agent { docker { image 'python:3.12-slim' } }
      environment {
        PIP_DISABLE_PIP_VERSION_CHECK = '1'
        PIP_NO_CACHE_DIR = '1'
      }
      steps {
        sh '''
          python -m venv .venv
          . .venv/bin/activate
          pip install --quiet -r requirements-dev.txt
          mkdir -p reportes
          pytest --junitxml=reportes/pruebas.xml
        '''
      }
      post {
        // Publica el reporte JUnit aunque las pruebas fallen
        always { junit testResults: 'reportes/pruebas.xml', allowEmptyResults: true }
      }
    }
    stage('Construir imagen') {
      agent any
      steps {
        sh 'docker build -t "$IMAGEN" .'
      }
    }
    stage('Prueba de humo') {
      agent any
      steps {
        // Reintenta GET /salud hasta obtener HTTP 200 y {"estado": "ok"} (máx. 30 s)
        sh 'HUMO_TIMEOUT=30 sh scripts/prueba_humo.sh "$IMAGEN" "$CONTENEDOR"'
      }
      post {
        // Limpieza garantizada del contenedor temporal, pase o falle la etapa
        always { sh 'docker rm -f "$CONTENEDOR" >/dev/null 2>&1 || true' }
      }
    }
  }
  post {
    success { echo "Build ${env.BUILD_NUMBER} OK: imagen ${env.IMAGEN} lista" }
    failure { echo 'El pipeline falló: revisa la etapa en rojo' }
  }
}
