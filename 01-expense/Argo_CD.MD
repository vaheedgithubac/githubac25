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
### Explanation
👉 `service.email` → Uses environment variables from the Secret  
👉 `template.*` → Defines email subject & body  
👉 `trigger.*` → Maps Argo CD events to templates  
👉 Now `on-sync-failed` exists and matches ApplicationSet annotations

## STEP 4️⃣ — Link ConfigMap with Secret

The Notifications controller automatically resolves environment variables from Secrets if properly mounted.  
You may need to patch the Deployment to ensure it reads from the Secret:

```bash
kubectl patch deployment argocd-notifications-controller -n argocd --patch '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "argocd-notifications-controller",
          "envFrom": [{
            "secretRef": { "name": "argocd-notifications-secret" }
          }]
        }]
      }
    }
  }
}'
```
Now restart the controller: 
```bash
kubectl rollout restart deployment argocd-notifications-controller -n argocd
```
✅ Now Notifications controller can read SMTP credentials securely.

## STEP 5️⃣ — AppProject with ClusterResourceWhitelist

Create an **AppProject** in Argo CD to group and manage all Expense microservice applications, define allowed Git repos, destinations, and roles:
`AppProject.yml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: expense-project
  namespace: argocd
spec:
  description: Project for expense microservice

  sourceRepos:
    - "https://github.com/my-org/my-repo.git"

  destinations:
    - namespace: "expense-*"
      server: https://kubernetes.default.svc

  clusterResourceWhitelist:
    - group: ""
      kind: "Namespace"

  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"

  roles:
    - name: frontend-admin
      policies:
        - p, proj:expense:frontend-admin, applications, *, expense/expense-*-frontend, allow

    - name: backend-admin
      policies:
        - p, proj:expense:backend-admin, applications, *, expense/expense-*-backend, allow

    - name: database-admin
      policies:
        - p, proj:expense:database-admin, applications, *, expense/expense-*-database, allow

    - name: expense-admin
      policies:
        - p, proj:expense:expense-admin, applications, *, expense/*, allow
```
### Explanation

👉 `clusterResourceWhitelist` → Allows Helm charts to deploy ClusterRole, CRDs, etc.  
👉 `namespaceResourceWhitelist` → Allows namespace-level objects  
👉 `destinations` → Only "expense-*" namespace (or matching `expense-*`) is allowed

Apply the yaml file
```bash
kubectl apply -f AppProject.yml
```




