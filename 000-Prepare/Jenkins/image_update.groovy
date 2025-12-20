pipeline {
  agent any
  environment {
    GITHUB_CREDENTIALS_ID = 'github-token'
  }
  stages{
      stage('Update image tag') {
                  steps {
                      script {
                          def imageTag = env.COMMIT_HASH
      
                           sh 'git checkout main'
      
                          // Use 'sed' to replace the image tag in values.yaml
                          sh """
                              sed -i 's/tag:.*/tag: ${imageTag}/' k8chart/values.yaml
                          """
      
                          withCredentials([
                              gitUsernamePassword(credentialsId: GITHUB_CREDENTIALS_ID, gitToolName: 'Default')
                          ]) {
                              sh """
                                   git config user.email "kodedge-bot-ci@kodedge.com"
                                   git config user.name "kodedge-bot-ci"
                                   git add k8chart/values.yaml
                                   git commit -m "Update image tag to version ${imageTag}"
                                   git push origin main
                              """
                          }
                      }
                  }
              }
      }
}
