## ArgoCD - KillerCoda   
1. ArgoCD Installation   
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
 - ArgoCD secret retrieval   
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```
2. Disable TLS Redirect   
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

3. Change Service to NodePort   
```bash
kubectl patch svc argocd-server -n argocd \
-p '{"spec": {"type": "NodePort"}}'
```


