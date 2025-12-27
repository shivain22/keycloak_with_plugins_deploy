pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    environment {
        // Docker Compose project name to avoid conflicts
        COMPOSE_PROJECT_NAME = 'keycloak-deployment'
        
        // Default Keycloak port (can be overridden in .env)
        KEYCLOAK_PORT = '8080'
        
        // Health check timeout
        HEALTH_CHECK_TIMEOUT = '300'
    }

    triggers {
        // Trigger on push to master branch
        githubPush()
        
        // Alternative: Poll SCM every 5 minutes (if webhooks not configured)
        // pollSCM('H/5 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "Checking out code from ${env.GIT_BRANCH}"
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
                }
            }
        }

        stage('Stop Existing Deployment') {
            steps {
                script {
                    echo "=== Stopping Existing Deployment ==="
                    sh '''
                        cd "${WORKSPACE}"
                        docker compose -p "${COMPOSE_PROJECT_NAME}" down || true
                        
                        # Clean up any orphaned containers
                        docker ps -a --filter "name=keycloak" --format "{{.ID}}" | xargs -r docker rm -f || true
                        docker ps -a --filter "name=keycloak-db" --format "{{.ID}}" | xargs -r docker rm -f || true
                        docker ps -a --filter "name=keycloak-artifacts-builder" --format "{{.ID}}" | xargs -r docker rm -f || true
                    '''
                }
            }
        }

        stage('Build Artifacts') {
            steps {
                script {
                    echo "=== Building Artifacts (Providers) ==="
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Build artifacts container
                        docker compose -p "${COMPOSE_PROJECT_NAME}" build artifacts || {
                            echo "ERROR: Failed to build artifacts image"
                            exit 1
                        }
                        
                        # Run artifacts build
                        docker compose -p "${COMPOSE_PROJECT_NAME}" run --rm artifacts || {
                            echo "ERROR: Artifacts build failed"
                            exit 1
                        }
                        
                        # Verify artifacts were created
                        if [ ! -f "providers/keycloak-phone-provider.jar" ] || \
                           [ ! -f "providers/keycloak-phone-provider-msg91.jar" ]; then
                            echo "ERROR: Required provider JARs not found!"
                            exit 1
                        fi
                        
                        echo "Artifacts built successfully:"
                        ls -lh providers/
                    '''
                }
            }
        }

        stage('Deploy Services') {
            steps {
                script {
                    echo "=== Deploying Keycloak Services ==="
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Start Postgres and Keycloak
                        docker compose -p "${COMPOSE_PROJECT_NAME}" up -d || {
                            echo "ERROR: Failed to start services"
                            docker compose -p "${COMPOSE_PROJECT_NAME}" logs
                            exit 1
                        }
                        
                        echo "Services started. Waiting for containers to be ready..."
                        sleep 10
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
                        if [ -f .env ]; then
                            KEYCLOAK_PORT=$(grep -E "^KEYCLOAK_HTTP_PORT=" .env 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "8080")
                        else
                            KEYCLOAK_PORT="8080"
                        fi
                        
                        echo "Checking Keycloak health on port ${KEYCLOAK_PORT}..."
                        
                        # Wait for Keycloak to be ready
                        MAX_WAIT=${HEALTH_CHECK_TIMEOUT}
                        ELAPSED=0
                        INTERVAL=10
                        
                        while [ ${ELAPSED} -lt ${MAX_WAIT} ]; do
                            if curl -f -s "http://localhost:${KEYCLOAK_PORT}/health/ready" > /dev/null 2>&1; then
                                echo "Keycloak is ready!"
                                break
                            fi
                            
                            echo "Waiting for Keycloak... (${ELAPSED}s/${MAX_WAIT}s)"
                            sleep ${INTERVAL}
                            ELAPSED=$((ELAPSED + INTERVAL))
                        done
                        
                        if [ ${ELAPSED} -ge ${MAX_WAIT} ]; then
                            echo "ERROR: Keycloak health check timeout!"
                            echo "Container logs:"
                            docker compose -p "${COMPOSE_PROJECT_NAME}" logs keycloak --tail 50
                            exit 1
                        fi
                        
                        # Check if Keycloak is responding
                        if ! curl -f -s "http://localhost:${KEYCLOAK_PORT}/health/ready" > /dev/null; then
                            echo "ERROR: Keycloak health check failed!"
                            docker compose -p "${COMPOSE_PROJECT_NAME}" logs keycloak --tail 50
                            exit 1
                        fi
                        
                        echo "Keycloak health check passed!"
                        echo "Keycloak is available at: http://localhost:${KEYCLOAK_PORT}"
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo "=== Verifying Deployment ==="
                    sh '''
                        cd "${WORKSPACE}"
                        
                        # Check container status
                        echo "Container status:"
                        docker compose -p "${COMPOSE_PROJECT_NAME}" ps
                        
                        # Verify all containers are running
                        if ! docker compose -p "${COMPOSE_PROJECT_NAME}" ps | grep -q "Up"; then
                            echo "ERROR: Some containers are not running!"
                            docker compose -p "${COMPOSE_PROJECT_NAME}" ps
                            exit 1
                        fi
                        
                        # Check Keycloak admin console is accessible
                        if [ -f .env ]; then
                            KEYCLOAK_PORT=$(grep -E "^KEYCLOAK_HTTP_PORT=" .env 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "8080")
                        else
                            KEYCLOAK_PORT="8080"
                        fi
                        
                        if curl -f -s "http://localhost:${KEYCLOAK_PORT}" > /dev/null 2>&1; then
                            echo "✓ Keycloak is accessible"
                        else
                            echo "WARNING: Keycloak may not be fully ready yet"
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

