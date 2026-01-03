## **KIND, ARGOCD, HELM and KUBECTL Installation**  
`Minimum: t2.small/t3.small  (2GB RAM)`   
 `Sufficient: t2.medium/t3.medium  (4GB RAM)`

## 1. Docker should be installed
```bash
sudo yum update -y
sudo yum install docker
sudo usermod -aG docker ec2-user
sudo newgrp docker
sudo systemctl start docker
docker ps
```
## 2.Kubectl-1.31 Installation   
```bash
KUBECTL_VERSION="v1.31.0"

curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

kubectl version --client
kubectl version
```
**(or)**
```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.31.0/bin/linux/amd64/kubectl && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl
```

## 3. KIND-0.31.0 Installation
```bash
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

## 4. KIND Cluster Creation  
`kind-cluster.yaml`   
```yaml
# kind-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: dev

# Specify the Kubernetes version by using a specific node image
# Visit https://hub.docker.com/r/kindest/node/tags and https://github.com/kubernetes-sigs/kind/releases for available images
nodes:
  - role: control-plane
    image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30 # Replace with the Kubernetes version you want
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        #listenAddress: "0.0.0.0" # Exposes port 80 to all host interfaces
      - containerPort: 443
        hostPort: 443
        #listenAddress: "0.0.0.0" # Exposes port 443 to all host interfaces
      - containerPort: 30080
        hostPort: 30080
        #listenAddress: "0.0.0.0" # Exposes port 443 to all host interfaces
      - containerPort: 8080
        hostPort: 8080
        #listenAddress: "0.0.0.0" # Exposes port 443 to all host interfaces

  - role: worker
    image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30
  - role: worker
    image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30
```
- Apply the above `kind-cluster.yaml` to create the KIND cluster    
`kind create cluster --config=kind-cluster.yaml`   

## 5.Execute following commands to check about cluster
- To get the kube/config file
```bash
kind export kubeconfig --name {{cluster_name}}
```
- Check all the Contexts (Clusters) 
```bash 
kubectl config get-contexts
```
- Check currently to which context(cluster) we are connected to   
`context = user + cluster + namespace`
```bash
kubectl config current-context
```
- Switch to a particular namespace   
```bash
kubectl config set-context --current --namespace={{namespace}}
```
- Switch to another Cluster
```bash
kubectl config use-context {{user}}@{{cluster_name}}
```

## 6. ArgoCD Installation   
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
- ArgoCD secret retrieval to login (For version 1.9 or later)   
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## 7. Patch the argocd-server service to be accessible on `30080`   
```bash
kubectl patch svc argocd-server -n argocd --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/type",
        "value": "NodePort"
      },
      {
        "op": "add",
        "path": "/spec/ports/1/nodePort",
        "value": 30080
      }
]'
```

## 8. Check the service    
```bash
kubectl get svc argocd-server -n argocd -o yaml > argocd-server.yaml
cat argocd-server.yaml
```
- You will see `type: NodePort` and `nodeport: 30080`  

## 9. Access the ArgoCD using `<public-IP>:30080`   

## 10. ArgoCD CLI Installation
```bash
sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd
```

## 10. HELM Installation   
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh

helm version
```

## 11. Trouble Shooting Commands   
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


