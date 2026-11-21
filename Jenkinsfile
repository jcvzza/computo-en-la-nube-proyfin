// Pipeline MediSur: del push a produccion sin pasos manuales
// CI: checkout -> secretos (gitleaks) -> pruebas -> sonarqube + quality gate -> hadolint -> build -> trivy -> push a ghcr
// CD: despliegue en k3s -> rollout status -> prueba de humo -> si algo falla, rollback automatico
pipeline {
    agent any

    //revisamos el repo cada 2 minutos; jenkins no esta abierto a internet, asi que no usamos webhook
    triggers {
        pollSCM('H/2 * * * *')
    }

    options {
        timestamps()
        timeout(time: 25, unit: 'MINUTES')
        //no dejamos que dos builds desplieguen al mismo tiempo
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        //registro y nombre de la imagen en ghcr (el dueno va en minusculas)
        IMAGEN = 'ghcr.io/jcvzza/medisur-app'
        //la version cambia sola en cada build para que ninguna etiqueta se sobrescriba
        APP_VERSION = "1.0.${env.BUILD_NUMBER}"
        //la app se publica por el nodeport 30080 de vm-k8s (ip privada, misma red que vm-tools)
        APP_URL = 'http://172.16.0.5:30080'
        //versiones fijas de las herramientas de seguridad
        GITLEAKS_IMG = 'zricethezav/gitleaks:v8.18.4'
        HADOLINT_IMG = 'hadolint/hadolint:v2.12.0'
        TRIVY_IMG = 'aquasec/trivy:0.56.2'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    //sacamos el sha corto del commit exacto que se va a construir
                    env.SHA_CORTO = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
                    env.BUILD_DATE = sh(script: 'date -u +%Y-%m-%dT%H:%M:%SZ', returnStdout: true).trim()
                }
                echo "Commit: ${env.SHA_CORTO} | Version: ${env.APP_VERSION}"
            }
        }

        stage('Secretos (gitleaks)') {
            steps {
                //revisamos todo el historial de git; si aparece un token o llave, el pipeline se detiene
                //corremos con el mismo usuario que jenkins para que git no rechace el repo por ser de otro dueno
                sh 'docker run --rm -u "$(id -u):$(id -g)" -v "$WORKSPACE:/repo" $GITLEAKS_IMG detect --source /repo --no-banner --redact'
            }
        }

        stage('Pruebas') {
            steps {
                dir('app') {
                    sh '''
                        python3 -m venv .venv
                        . .venv/bin/activate
                        pip install -q -r requirements-dev.txt
                        python -m pytest --cov=app --cov-report=xml:coverage.xml -q
                    '''
                }
            }
        }

        stage('SonarQube y Quality Gate') {
            steps {
                dir('app') {
                    withSonarQubeEnv('sonarqube') {
                        //qualitygate.wait hace que el escaner espere el resultado y falle si el gate no pasa
                        sh "${SCANNER_HOME}/bin/sonar-scanner -Dsonar.qualitygate.wait=true -Dsonar.qualitygate.timeout=300"
                    }
                }
            }
        }

        //si algo de arriba falla, el pipeline se detiene y nunca se construye la imagen
        stage('Dockerfile (hadolint)') {
            steps {
                sh 'docker run --rm -i $HADOLINT_IMG hadolint - < app/Dockerfile'
            }
        }

        stage('Docker build') {
            steps {
                dir('app') {
                    //inyectamos version, sha y fecha para que /version diga exactamente que se construyo
                    sh '''
                        docker build \
                          --build-arg APP_VERSION=$APP_VERSION \
                          --build-arg GIT_SHA=$SHA_CORTO \
                          --build-arg BUILD_DATE=$BUILD_DATE \
                          -t $IMAGEN:$SHA_CORTO \
                          -t $IMAGEN:$APP_VERSION \
                          .
                    '''
                }
            }
        }

        stage('Vulnerabilidades (trivy)') {
            steps {
                //si la imagen trae vulnerabilidades altas o criticas con parche disponible, no se publica
                sh '''
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      -v trivy-cache:/root/.cache \
                      $TRIVY_IMG image --quiet --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed $IMAGEN:$SHA_CORTO
                '''
            }
        }

        stage('Push a GHCR') {
            steps {
                //el token vive solo en las credenciales de jenkins, nunca en el repo
                withCredentials([usernamePassword(credentialsId: 'jenkins-ghcr', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
                    sh '''
                        echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
                        docker push $IMAGEN:$SHA_CORTO
                        docker push $IMAGEN:$APP_VERSION
                    '''
                }
            }
        }

        stage('Despliegue en k3s') {
            steps {
                //el kubeconfig tambien vive en las credenciales de jenkins, nunca en el repo
                withCredentials([file(credentialsId: 'kubeconfig-k3s', variable: 'KUBECONFIG')]) {
                    script {
                        //marcamos que ya tocamos el cluster para saber si hay que hacer rollback
                        env.DESPLIEGUE_INICIADO = 'true'
                    }
                    //aplica los manifiestos con la imagen del sha, espera el rollout y hace la prueba de humo
                    sh 'bash scripts/desplegar.sh $IMAGEN $SHA_CORTO $APP_VERSION $APP_URL'
                }
            }
        }
    }

    post {
        failure {
            script {
                //si el despliegue o la prueba de humo fallaron, regresamos solos a la version anterior
                if (env.DESPLIEGUE_INICIADO == 'true') {
                    withCredentials([file(credentialsId: 'kubeconfig-k3s', variable: 'KUBECONFIG')]) {
                        sh 'bash scripts/rollback.sh'
                    }
                }
            }
        }
        always {
            //cerramos sesion y borramos las imagenes locales para no llenar el disco de vm-tools
            sh '''
                docker logout ghcr.io || true
                docker rmi $IMAGEN:$SHA_CORTO $IMAGEN:$APP_VERSION || true
            '''
        }
    }
}
