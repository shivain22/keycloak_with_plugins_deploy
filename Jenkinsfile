pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    triggers {
        // Trigger on push to main/master branch via GitHub webhook
        githubPush()
        
        // Alternative: Poll SCM every 5 minutes (if webhooks not configured)
        // pollSCM('H/5 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "=== Checking out code ==="
                    checkout scm
                    
                    // Display commit information
                    sh '''
                        echo "=== Git Information ==="
                        echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
                        echo "Commit: $(git rev-parse HEAD)"
                        echo "Author: $(git log -1 --pretty=format:'%an <%ae>')"
                        echo "Message: $(git log -1 --pretty=format:'%s')"
                    '''
                }
            }
        }

        stage('Validate Environment') {
            steps {
                script {
                    echo "=== Validating Environment ==="
                    
                    // Check if .env file exists, if not create from template
                    sh '''
                        if [ ! -f .env ]; then
                            echo "WARNING: .env file not found. Creating from env.example..."
                            if [ -f env.example ]; then
                                cp env.example .env
                                echo "Created .env from env.example. Please review and update values."
                            elif [ -f env.template ]; then
                                cp env.template .env
                                echo "Created .env from env.template. Please review and update values."
                            else
                                echo "ERROR: No env.example or env.template found!"
                                exit 1
                            fi
                        fi
                    '''
                    
                    // Check Docker and Docker Compose availability
                    sh '''
                        echo "Checking Docker installation..."
                        docker --version || { echo "ERROR: Docker not found!"; exit 1; }
                        docker compose version || { echo "ERROR: Docker Compose not found!"; exit 1; }
                    '''
                    
                    // Make sure start.sh is executable
                    sh '''
                        chmod +x start.sh || true
                    '''
                }
            }
        }

        stage('Deploy using start.sh') {
            steps {
                script {
                    echo "=== Running start.sh to deploy Keycloak ==="
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Run the start.sh script
                        # This will:
                        # 1. Stop existing containers
                        # 2. Build artifacts
                        # 3. Start Postgres + Keycloak
                        ./start.sh
                        
                        echo "Deployment completed successfully!"
                    '''
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    echo "=== Performing Health Checks ==="
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Read Keycloak port from .env if available
                        KEYCLOAK_PORT="8080"
                        if [ -f .env ]; then
                            ENV_PORT=$(grep -E "^KEYCLOAK_HTTP_PORT=" .env 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "")
                            if [ -n "${ENV_PORT}" ]; then
                                KEYCLOAK_PORT="${ENV_PORT}"
                            fi
                        fi
                        
                        echo "Checking Keycloak health on port ${KEYCLOAK_PORT}..."
                        
                        # Wait for Keycloak to be ready (max 5 minutes)
                        MAX_WAIT=300
                        ELAPSED=0
                        INTERVAL=10
                        
                        while [ ${ELAPSED} -lt ${MAX_WAIT} ]; do
                            if curl -f -s "http://localhost:${KEYCLOAK_PORT}/health/ready" > /dev/null 2>&1; then
                                echo "✓ Keycloak is ready!"
                                break
                            fi
                            
                            echo "Waiting for Keycloak... (${ELAPSED}s/${MAX_WAIT}s)"
                            sleep ${INTERVAL}
                            ELAPSED=$((ELAPSED + INTERVAL))
                        done
                        
                        if [ ${ELAPSED} -ge ${MAX_WAIT} ]; then
                            echo "WARNING: Keycloak health check timeout!"
                            echo "Container logs:"
                            docker compose logs keycloak --tail 50
                            # Don't fail the build, just warn
                        else
                            echo "✓ Keycloak health check passed!"
                            echo "Keycloak is available at: http://localhost:${KEYCLOAK_PORT}"
                        fi
                    '''
                }
            }
        }
    }

    post {
        success {
            script {
                echo "=== Deployment Successful ==="
                sh '''
                    cd "${WORKSPACE}"
                    if [ -f .env ]; then
                        KEYCLOAK_PORT=$(grep -E "^KEYCLOAK_HTTP_PORT=" .env 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "8080")
                    else
                        KEYCLOAK_PORT="8080"
                    fi
                    echo "Keycloak deployed successfully!"
                    echo "Access Keycloak at: http://localhost:${KEYCLOAK_PORT}"
                    echo "Admin console: http://localhost:${KEYCLOAK_PORT}/admin"
                '''
            }
        }
        
        failure {
            script {
                echo "=== Deployment Failed ==="
                sh '''
                    cd "${WORKSPACE}"
                    echo "Collecting logs for troubleshooting..."
                    docker compose -p "${COMPOSE_PROJECT_NAME}" logs --tail 100 > deployment-logs.txt || true
                    echo "Logs saved to deployment-logs.txt"
                '''
                
                // Optionally, you can add email/Slack notifications here
                // emailext (
                //     subject: "Keycloak Deployment Failed - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                //     body: "Deployment failed. Check Jenkins for details.",
                //     to: "your-email@example.com"
                // )
            }
        }
        
        always {
            script {
                echo "=== Cleaning Up ==="
                // Keep containers running, but clean up build artifacts if needed
                sh '''
                    # Optional: Clean up old images
                    # docker image prune -f || true
                    echo "Deployment process completed"
                '''
            }
        }
    }
}

