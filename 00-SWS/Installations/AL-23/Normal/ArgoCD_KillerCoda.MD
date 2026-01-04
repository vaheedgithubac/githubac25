## ArgoCD - KillerCoda   
## 1. ArgoCD Installation   
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
 - ArgoCD secret retrieval   
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```
## 2. Disable TLS Redirect   
```bash
kubectl edit configmap argocd-cmd-params-cm -n argocd
```
Add:   
```yaml
data:
  server.insecure: "true"
```
Then restart:   
```bash
kubectl rollout restart deployment argocd-server -n argocd
```

## 3. Change Service to NodePort   
```bash
kubectl patch svc argocd-server -n argocd \
-p '{"spec": {"type": "NodePort"}}'
```

## 4. Helm Installation   
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh

helm version
```

## 5. Trouble Shooting Commands   
```bash
helm template frontend expense/app-code/frontend/CI-CD/CD/helm -f expense/app-code/frontend/CI-CD/CD/helm/values-dockerHub.yml

helm template backend expense/app-code/backend/CI-CD/CD/helm \
  -f expense/app-code/backend/CI-CD/CD/helm/values-dockerHub.yml \
  --dry-run=client --debug

helm template frontend expense/app-code/frontend/CI-CD/CD/helm \
  -f expense/app-code/frontend/CI-CD/CD/helm/values-dockerHub.yml \
  --debug --dry-run=client

helm template database expense/app-code/database/CI-CD/CD/helm \
  -f expense/app-code/database/CI-CD/CD/helm/values-dockerHub.yml \
  --dry-run=client --debug

 argocd app sync expense-dev-frontend
 argocd app sync expense-dev-backend
 argocd app sync expense-dev-database

 argocd login <ARGOCD_SERVER> \
  --username <USERNAME> \
  --password <PASSWORD> \
  [--insecure]
```


