
def tls_compose_file = 'docker-compose-tls.yml'
def vault_otp_ui_compose_file = 'docker-compose-vault-otp-ui.yml'

pipeline {
    agent none
    options {
        ansiColor('xterm')
    }
    environment {
        GITHUB_TOKEN = credentials('JENKINS_GITHUB_TOKEN_VAULT_ACCESS_TEXT')
    }
    stages {
        stage('build development template') {
            when {
              beforeAgent true
              not {
                tag "release-*"
              }
            }
            agent {
              node {
                label '20GB'
              }
            }
            environment {
              SHORT_COMMIT                  = sh(
                                                script: "printf \$(git rev-parse --short ${GIT_COMMIT})",
                                                returnStdout: true
                                              )
              PKR_VAR_artifact_identifier   = "${SHORT_COMMIT}_${BRANCH_NAME}_${BUILD_NUMBER}".replace('/','_')
            }
            steps {
                script {

                    /**
                    * create a deployment artifacts folder
                    * here the image tar file and the docker-compose.yml of the project will be placed so that packer later on can access these artifacts
                    */
                    dir("deployment-artifacts"){
                        writeFile file:'dummy', text:''
                    }
                    dir("deployment-artifacts/tls"){
                        writeFile file:'dummy', text:''
                    }
                    dir("deployment-artifacts/vault-otp-ui"){
                        writeFile file:'dummy', text:''
                    }
                    /**
                    * create an image tar based on the docker-compose.yml
                    **/
                    docker.withRegistry('https://medneo-docker.jfrog.io', 'jfrogDockerRegistryCredentials') {
                        def DOCKER_IMAGE_LIST = []
                        docker.image('opnm-deploy-tools:2.0.0').inside(){
                            sh "echo 'DOCKER_IMAGE_TAG=dummy' > /tmp/.env"
                            sh(
                                [
                                    script:"/usr/sbin/get_image_names.sh /tmp/.env ${tls_compose_file}",
                                    returnStdout: true
                                ]
                            ).split().each { 
                                DOCKER_IMAGE_LIST << it 
                            }
                            sh(
                                [
                                    script:"/usr/sbin/get_image_names.sh /tmp/.env ${vault_otp_ui_compose_file}",
                                    returnStdout: true
                                ]
                            ).split().each { 
                                DOCKER_IMAGE_LIST << it 
                            }
                        }
                        DOCKER_IMAGE_LIST.each {
                          sh "docker pull ${it}"
                        }
                        sh "docker save -o deployment-artifacts/images.tar ${DOCKER_IMAGE_LIST.join(' ')}"
                        docker.image('alpine:3.10').inside(){
                          sh "cp ${tls_compose_file} deployment-artifacts/tls/docker-compose.yml"
                          sh "cp ${vault_otp_ui_compose_file} deployment-artifacts/vault-otp-ui/docker-compose.yml"
                        }
                    }
                    /**
                    * trigger the packer build
                    */
                    docker.withRegistry('https://medneo-docker.jfrog.io', 'jfrogDockerRegistryCredentials') {
                        docker.image('medneo-docker.jfrog.io/packer-ansible:2.1.0').inside('--entrypoint=\'\' --user=root') {
                            sh "export VAULT_TOKEN=\$(/vault-auth.sh) && packer build ."
                        }
                    }
                }
            }
        }
        stage('build release template') {
            when {
              beforeAgent true
              tag "release-*"              
            }
            agent {
              node {
                label '20GB'
              }
            }
            environment {
                ARTIFACT_IDENTIFIER         = TAG_NAME.substring(8)
                PKR_VAR_artifact_identifier = "${ARTIFACT_IDENTIFIER}"
                PKR_VAR_is_release          = true
            }
            steps {
                script {

                    /**
                    * create a deployment artifacts folder
                    * here the image tar file and the docker-compose.yml of the project will be placed so that packer later on can access these artifacts
                    */
                    dir("deployment-artifacts"){
                        writeFile file:'dummy', text:''
                    }
                    dir("deployment-artifacts/tls"){
                        writeFile file:'dummy', text:''
                    }
                    dir("deployment-artifacts/vault-otp-ui"){
                        writeFile file:'dummy', text:''
                    }
                    /**
                    * create an image tar based on the docker-compose.yml
                    **/
                    docker.withRegistry('https://medneo-docker.jfrog.io', 'jfrogDockerRegistryCredentials') {
                        def DOCKER_IMAGE_LIST = []
                        docker.image('opnm-deploy-tools:2.0.0').inside(){
                            sh "echo 'DOCKER_IMAGE_TAG=dummy' > /tmp/.env"
                            sh(
                                [
                                    script:"/usr/sbin/get_image_names.sh /tmp/.env ${tls_compose_file}",
                                    returnStdout: true
                                ]
                            ).split().each { 
                                DOCKER_IMAGE_LIST << it 
                            }
                            sh(
                                [
                                    script:"/usr/sbin/get_image_names.sh /tmp/.env ${vault_otp_ui_compose_file}",
                                    returnStdout: true
                                ]
                            ).split().each { 
                                DOCKER_IMAGE_LIST << it 
                            }
                        }
                        DOCKER_IMAGE_LIST.each {
                          sh "docker pull ${it}"
                        }
                        sh "docker save -o deployment-artifacts/images.tar ${DOCKER_IMAGE_LIST.join(' ')}"
                        docker.image('alpine:3.10').inside(){
                          sh "cp ${tls_compose_file} deployment-artifacts/tls/docker-compose.yml"
                          sh "cp ${vault_otp_ui_compose_file} deployment-artifacts/vault-otp-ui/docker-compose.yml"
                        }
                    }
                    /**
                    * trigger the packer build
                    */
                    docker.withRegistry('https://medneo-docker.jfrog.io', 'jfrogDockerRegistryCredentials') {
                        docker.image('medneo-docker.jfrog.io/packer-ansible:2.1.0').inside('--entrypoint=\'\' --user=root') {
                            sh "export VAULT_TOKEN=\$(/vault-auth.sh) && packer build ."
                        }
                    }
                }
            }
        }
    }
}