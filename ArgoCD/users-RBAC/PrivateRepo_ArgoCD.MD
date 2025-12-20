## 2️⃣ HTTPS-based Repository Secret (Complete YAML)
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

## 2️⃣ SSH-based Repository Secret (Complete YAML)
