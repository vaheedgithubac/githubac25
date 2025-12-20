## 1️⃣ HTTPS-based Repository Secret (Complete YAML)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-token
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: https://github.com/kodedge-swapneel/exchangerates.git
  username: your_username@gmail.com
  password: token
```

## 2️⃣ SSH-based Repository Secret (Complete YAML)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-ssh-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: git@github.com:my-org/my-repo.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    your-private-key-content-here
    -----END OPENSSH PRIVATE KEY-----
```

## 🔹 How Argo CD uses this secret (flow)   
1.**Argo CD starts**  
2.**Scans argocd namespace**  
3.**Finds secrets with label:**  
```yaml
argocd.argoproj.io/secret-type: repository
```
4.**Reads:** 
  - `url` 
  - `username` 
  - `password`   
**5.When syncing an Application:**
  - `Matches repoURL`
  - `Uses stored credentials`
  - `Authenticates to GitHub`
  - `Pulls manifests`
