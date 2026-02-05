## 🧠 Big Picture (understand first)
```text
Private Docker Registry
        ↑
Docker credentials (Secret)
        ↑
ServiceAccount
        ↑
Pod / Deployment
```
- Pods do NOT talk to Docker Hub directly.
- Kubernetes pulls the image on behalf of the Pod, using the ServiceAccount’s imagePullSecrets.

1️⃣ Prerequisites (must-have)
- A **private Docker image**, for example:
```text
docker.io/myusername/my-private-image:latest
```
- Docker Hub:
  - Username
  - Access Token (NOT your password)
- Kubernetes cluster access
- Namespace (we’ll use `app`)

## 2️⃣ Create the namespace (if not exists)
```bash
kubectl create namespace app
```
## 3️⃣ Create Docker registry Secret (MOST IMPORTANT STEP)  
### ✅ RECOMMENDED & SAFEST METHOD (CLI)  
```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=DOCKERHUB_USERNAME \
  --docker-password=DOCKERHUB_ACCESS_TOKEN \
  --docker-email=your@email.com \
  -n app
```
**🔹 What this does:**  
  - Creates secret of type **kubernetes.io/dockerconfigjson**  
  - Generates valid **.dockerconfigjson**  
  - Handles base64 correctly 

## 🔹 OR 3.1 You can create your own secret yaml file
**Login to docker hub first using `docker login` command, then only `.dockerconfigjson` will be created automatically**   
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-secret
  namespace: app
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "https://index.docker.io/v1/": {
          "username": "DOCKERHUB_USERNAME",
          "password": "DOCKERHUB_ACCESS_TOKEN",
          "auth": "BASE64(username:token)"
        }
      }
    }
```
Note:  
1. If you use `stringData:`, then it's content should be plain text
2. If you use `data:`, then it's content should be `base64` encoded

🔍 Verify the secret  
```bash
kubectl get secret dockerhub-secret -n app

kubectl describe secret dockerhub-secret -n app
```
You should see:
```bash
Type: kubernetes.io/dockerconfigjson
```

## 4️⃣ Create a ServiceAccount that uses this secret 
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: app
imagePullSecrets:
- name: dockerhub-secret
```
Apply it:   
```bash
kubectl apply -f serviceaccount.yaml
```
**🔍 Verify ServiceAccount**
```bash
kubectl get sa app-sa -n app -o yaml
```
You MUST see:
```yaml
imagePullSecrets:
- name: dockerhub-secret
```

## 5️⃣ Create a Deployment that uses the ServiceAccount
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: private-app
  namespace: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: private-app
  template:
    metadata:
      labels:
        app: private-app
    spec:
      serviceAccountName: app-sa
      containers:
      - name: app
        image: docker.io/myusername/my-private-image:latest
        imagePullPolicy: Always
```
Apply it:
```bash
kubectl apply -f deployment.yaml
```
## 6️⃣ What happens internally (IMPORTANT)
**1. Pod is created**  
**2. Kubernetes sees:**  
```makefile
serviceAccountName: app-sa   
```
**3. ServiceAccount references:**  
```makefile
imagePullSecrets: dockerhub-secret
```
**4. kubelet authenticates to Docker Hub**  
**5. Private image is pulled**  
**6. Container starts**  

## 7️⃣ Verify everything works
**Check Pod status**
```bash
kubectl get pods -n app
```
You want:
```makefile
STATUS: Running
```
**If it fails, check events (VERY IMPORTANT)**  
```bash
kubectl describe pod <pod-name> -n app
```
## 8️⃣ Common errors & EXACT fixes
**❌ ImagePullBackOff**  
**Causes:**
  - Wrong image name
  - Wrong tag
  - Secret not attached to ServiceAccount
  - Wrong Docker Hub credentials  
**Fix:**
  - Double-check image name  
  - Recreate secret  
  - Ensure ServiceAccount is used  

## ❌ unauthorized: authentication required
**Causes:**
  - Using Docker password instead of token
  - Token expired or revoked
**Fix:**
  - Create Docker Hub Access Token  
  - Recreate secret  

❌ Pod stuck in Pending
**Cause:**
  - Image pull failure  
**Fix:**
```bash
kubectl describe pod <pod>
```

## 9️⃣ MOST COMMON MISTAKES (90% failures)
❌ Forgetting serviceAccountName in Deployment  
❌ Creating secret in wrong namespace  
❌ Typo in secret name  
❌ Using latest tag that doesn’t exist  
❌ Using email/password instead of token  

## 🔟 Docker Hub vs Other Registries    
**🔹 Amazon ECR**  
- Use IRSA (BEST) or docker-registry secret  
- Username = `AWS`  
- Password = ECR token  
**🔹 GitHub Container Registry** 
```bash
--docker-server=ghcr.io
--docker-username=github-username
--docker-password=ghp_xxx
```
## 🔹 Google Artifact Registry  
- Use JSON key as password

## 🧠 Final mental model
**ServiceAccount = identity**    
**Secret = credentials**   
**Pod = uses identity**  

## ✅ Production best practices  
✔ One ServiceAccount per app  
✔ One registry secret per namespace  
✔ Use tokens, never passwords  
✔ Rotate tokens periodically  
✔ For EKS → prefer IRSA  






