## **KIND, ARGOCD, HELM and KUBECTL Installation**  
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
curl -LO https://storage.googleapis.com/kubernetes-release/release/v0.31.0/bin/linux/amd64/kubectl && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl
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

## 5. ArgoCD Installation   
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## 6. Patch the argocd-server service to be accessible on `30080`   
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

## 7. Check the service    
```bash
kubectl get svc argocd-server -n argocd -o yaml > argocd-server.yaml
cat argocd-server.yaml
```
- You will see `type: NodePort` and `nodeport: 30080`  

## 8. Access the ArgoCD using `<public-IP>:30080`

