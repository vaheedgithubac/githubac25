# Expense Microservice Deployment 🚀

GitOps-based deployment of the Expense microservice using **Argo CD**, **Helm**, and **ApplicationSet**.

---

## Git Repo Structure

```text
expense/
└── cd/
    └── argocd/
        └── dev/
            ├── frontend/
            │   └── helm/
            │       ├── Chart.yaml
            │       ├── values.yml
            │       └── templates/
            │           ├── deployment.yaml
            │           └── service.yaml
            ├── backend/
            │   └── helm/
            │       ├── Chart.yaml
            │       ├── values.yml
            │       └── templates/
            │           ├── deployment.yaml
            │           └── service.yaml
            └── database/
                └── helm/
                    ├── Chart.yaml
                    ├── values.yml
                    └── templates/
                        ├── deployment.yaml
                        ├── service.yaml
                        └── pvc.yaml
```

## STEP 0️⃣ — Assumptions

👉 Kubernetes cluster exists  
👉 Argo CD is installed in the `argocd` namespace  
👉 You have access to a Git repository  
👉 You have SMTP credentials to send emails  
👉 We will configure the Argo CD Notifications controller using a **Kubernetes Secret** for email credentials  

## STEP 1️⃣ — Install Argo CD Notifications Controller

Install the Notifications controller in the `argocd` namespace:

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/stable/manifests/install.yaml
```
Check that the Notifications controller pods are running:
```bash
kubectl get pods -n argocd

NAME                                   READY   STATUS    RESTARTS   AGE
argocd-notifications-controller-xxxxx  1/1     Running   0          1m
```
## STEP 2️⃣ — Create Secret for Email

We don’t store passwords in plain ConfigMaps. Let’s create a **Kubernetes Secret** for Argo CD Notifications in `argocd` namespace:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
stringData:
  smtp-host: smtp.example.com
  smtp-port: "587"
  smtp-from: argocd@example.com
  smtp-username: argocd@example.com
  smtp-password: examplepassword
```
Apply it:
```bash
kubectl apply -f argocd-notifications-secret.yaml
```

## STEP 3️⃣ — Create ConfigMap for Notifications Controller

Create a **ConfigMap** to configure notification templates and triggers for Argo CD:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.email: |
    host: $smtp-host
    port: $smtp-port
    from: $smtp-from
    username: $smtp-username
    password: $smtp-password

  # Notification templates
  template.app-deployed: |
    message: "Application {{.app.metadata.name}} deployed successfully"
    subject: "[ArgoCD] {{.app.metadata.name}} Deployed"

  template.app-health-degraded: |
    message: "Application {{.app.metadata.name}} is degraded"
    subject: "[ArgoCD] {{.app.metadata.name}} Health Degraded"

  template.app-sync-failed: |
    message: "Application {{.app.metadata.name}} sync failed"
    subject: "[ArgoCD] {{.app.metadata.name}} Sync Failed"

  # Notification triggers
  trigger.on-deployed: |
    - description: Application successfully deployed
    - send: [app-deployed]

  trigger.on-health-degraded: |
    - description: Application degraded
    - send: [app-health-degraded]

  trigger.on-sync-failed: |
    - description: Application sync failed
    - send: [app-sync-failed]
```

Apply the ConfigMap:
```bash
kubectl apply -f argocd-notifications-cm.yaml
```



