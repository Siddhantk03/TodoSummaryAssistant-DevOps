pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
    skipDefaultCheckout(true)
  }

  triggers {
    pollSCM('H/5 * * * *')
  }

  environment {
    PATH = '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin'
    DOCKERHUB_NAMESPACE = 'siddhantk03'
    DOCKERHUB_CREDENTIALS_ID = 'dockerhub-credentials'
    REACT_APP_API_BASE_URL = '/api'
  }

  stages {
    stage('Checkout and prepare tags') {
      steps {
        checkout scm
        script {
          env.GIT_SHA = sh(
            script: 'git rev-parse --short=12 HEAD',
            returnStdout: true
          ).trim()

          env.BACKEND_IMAGE = "docker.io/${env.DOCKERHUB_NAMESPACE}/todo-backend"
          env.FRONTEND_IMAGE = "docker.io/${env.DOCKERHUB_NAMESPACE}/todo-frontend"

          def suffix = "${env.BUILD_TAG}-${java.util.UUID.randomUUID().toString().take(8)}"
          env.CI_DB_CONTAINER = "todo-ci-db-${suffix}".replaceAll(/[^A-Za-z0-9_.-]/, '-')
        }
      }
    }

    stage('Start temporary MySQL for backend tests') {
      steps {
        sh '''
          set -eu

          docker run -d \
            --name "$CI_DB_CONTAINER" \
            -p 127.0.0.1::3306 \
            --health-cmd='mysqladmin ping -h 127.0.0.1' \
            --health-interval=5s \
            --health-timeout=3s \
            --health-retries=30 \
            --health-start-period=20s \
            -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
            -e MYSQL_DATABASE=todo_db \
            mysql:8.0

          test -n "$(docker port "$CI_DB_CONTAINER" 3306/tcp)"

          attempt=0
          until [ "$(docker inspect --format '{{.State.Health.Status}}' "$CI_DB_CONTAINER")" = "healthy" ]; do
            attempt=$((attempt + 1))

            if [ "$attempt" -ge 60 ]; then
              docker logs "$CI_DB_CONTAINER"
              exit 1
            fi

            sleep 2
          done
        '''

        script {
          def mappedPort = sh(
            script: "docker port ${env.CI_DB_CONTAINER} 3306/tcp",
            returnStdout: true
          ).trim()

          env.CI_DB_PORT = mappedPort.tokenize(':').last()
        }
      }
    }

    stage('Build and test backend') {
      steps {
        dir('Backend/todo-summary-assistant') {
          withEnv([
            "SPRING_DATASOURCE_URL=jdbc:mysql://127.0.0.1:${env.CI_DB_PORT}/todo_db?createDatabaseIfNotExist=true",
            'SPRING_DATASOURCE_USERNAME=root',
            'SPRING_DATASOURCE_PASSWORD=root'
          ]) {
            sh 'mvn -B clean verify'
          }
        }
      }

      post {
        always {
          junit allowEmptyResults: true,
            testResults: 'Backend/todo-summary-assistant/**/target/surefire-reports/*.xml'
        }
      }
    }

    stage('Build and test frontend') {
      steps {
        dir('Frontend/todo') {
          sh 'npm ci'
          sh 'npm test -- --watchAll=false --passWithNoTests'
          sh 'CI=false npm run build'
        }
      }
    }

    stage('Build and push SHA-tagged images') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: env.DOCKERHUB_CREDENTIALS_ID,
            usernameVariable: 'DOCKERHUB_USERNAME',
            passwordVariable: 'DOCKERHUB_TOKEN'
          )
        ]) {
          sh '''
            set -eu

            printf '%s' "$DOCKERHUB_TOKEN" \
              | docker login --username "$DOCKERHUB_USERNAME" --password-stdin

            docker build \
              -f Dockerfile.backend \
              -t "$BACKEND_IMAGE:$GIT_SHA" .

            docker build \
              -f Dockerfile.frontend \
              --build-arg REACT_APP_API_BASE_URL="$REACT_APP_API_BASE_URL" \
              -t "$FRONTEND_IMAGE:$GIT_SHA" .

            docker push "$BACKEND_IMAGE:$GIT_SHA"
            docker push "$FRONTEND_IMAGE:$GIT_SHA"

            docker logout
          '''
        }
      }
    }
  }

  post {
    always {
      script {
        if (env.CI_DB_CONTAINER) {
          sh 'docker rm -f "$CI_DB_CONTAINER" >/dev/null 2>&1 || true'
        }

        if (env.GIT_SHA && env.BACKEND_IMAGE && env.FRONTEND_IMAGE) {
          sh '''
            docker image rm -f \
              "$BACKEND_IMAGE:$GIT_SHA" \
              "$FRONTEND_IMAGE:$GIT_SHA" \
              >/dev/null 2>&1 || true
          '''
        }
      }
    }
  }
}