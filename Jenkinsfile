pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds(); skipDefaultCheckout(true) }
  triggers { pollSCM('H/5 * * * *') }
  environment {
    REGISTRY = 'docker.io'
    IMAGE_NAMESPACE = 'REPLACE_WITH_REGISTRY_NAMESPACE'
    BACKEND_IMAGE = "${REGISTRY}/${IMAGE_NAMESPACE}/todo-backend"
    FRONTEND_IMAGE = "${REGISTRY}/${IMAGE_NAMESPACE}/todo-frontend"
    REGISTRY_CREDENTIALS = 'container-registry-credentials'
  }
  stages {
    stage('Checkout') {
      steps { checkout scm; script { env.GIT_SHA = sh(script: 'git rev-parse --short=12 HEAD', returnStdout: true).trim() } }
    }
    stage('Build and test backend') {
      steps { dir('Backend/todo-summary-assistant') { sh 'mvn -B clean verify' } }
      post { always { junit allowEmptyResults: true, testResults: 'Backend/todo-summary-assistant/**/target/surefire-reports/*.xml' } }
    }
    stage('Build frontend') {
      steps { dir('Frontend/todo') { sh 'npm ci && npm run build' } }
    }
    stage('Build and push images') {
      steps {
        script {
          docker.withRegistry("https://${env.REGISTRY}", env.REGISTRY_CREDENTIALS) {
            sh "docker build -f Dockerfile.backend -t ${BACKEND_IMAGE}:${GIT_SHA} ."
            sh "docker build -f Dockerfile.frontend --build-arg REACT_APP_API_BASE_URL=/api -t ${FRONTEND_IMAGE}:${GIT_SHA} ."
            sh "docker push ${BACKEND_IMAGE}:${GIT_SHA}"
            sh "docker push ${FRONTEND_IMAGE}:${GIT_SHA}"
          }
        }
      }
    }
  }
  post { always { sh 'docker image prune -f || true' } }
}
