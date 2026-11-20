// Pipeline MediSur - etapa 1: calidad (pruebas + SonarQube + quality gate)
pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
    }

    environment {
        SCANNER_HOME = tool 'sonar-scanner'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Pruebas') {
            steps {
                dir('app') {
                    sh '''
                        python3 -m venv .venv
                        . .venv/bin/activate
                        pip install -q -r requirements-dev.txt
                        pytest --cov=app --cov-report=xml:coverage.xml -q
                    '''
                }
            }
        }

        stage('SonarQube y Quality Gate') {
            steps {
                dir('app') {
                    withSonarQubeEnv('sonarqube') {
                        // qualitygate.wait hace que el escaner espere el resultado y falle si el gate no pasa
                        sh "${SCANNER_HOME}/bin/sonar-scanner -Dsonar.qualitygate.wait=true -Dsonar.qualitygate.timeout=300"
                    }
                }
            }
        }
    }
}