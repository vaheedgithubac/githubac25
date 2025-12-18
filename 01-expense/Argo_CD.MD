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
            │       ├── Chart.yml
            │       ├── values.yml
            │       └── templates/
            │           ├── deployment.yml
            │           └── service.yml
            ├── backend/
            │   └── helm/
            │       ├── Chart.yaml
            │       ├── values.yml
            │       └── templates/
            │           ├── deployment.yml
            │           └── service.yml
            └── database/
                └── helm/
                    ├── Chart.yaml
                    ├── values.yml
                    └── templates/
                        ├── deployment.yml
                        ├── service.yml
                        └── pvc.yml
```
#### Explanation

👉 `Chart.yml` → Defines the Helm chart metadata (name, version, type, appVersion)  
👉 `values.yml` → Stores component-specific configurable values  
👉 `templates/` → Contains Kubernetes manifests (Deployment, Service, PVC)  
👉 Each component has its own Helm chart, allowing isolated deployments and ApplicationSet mapping


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
`argocd-notifications-secret.yml`
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
kubectl apply -f argocd-notifications-secret.yml
```

## STEP 3️⃣ — Create ConfigMap for Notifications Controller

Create a **ConfigMap** to configure notification templates and triggers for Argo CD:
`argocd-notifications-cm.yaml`
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

Create an **AppProject** in Argo CD in `argocd` namespace to group and manage all Expense microservice applications, define allowed Git repos, destinations, and roles:

`AppProject.yml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject   # This will be used to group 'Applications' under this Project
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
        - p, proj:expense-project:frontend-admin, applications, *, expense/expense-*-frontend, allow

    - name: backend-admin
      policies:
        - p, proj:expense-project:backend-admin, applications, *, expense/expense-*-backend, allow

    - name: database-admin
      policies:
        - p, proj:expense-project:database-admin, applications, *, expense/expense-*-database, allow

    - name: expense-admin
      policies:
        - p, proj:expense-project:expense-admin, applications, *, expense/*, allow
```
### Explanation

👉 `clusterResourceWhitelist` → Allows Helm charts to deploy ClusterRole, CRDs, etc.  
👉 `namespaceResourceWhitelist` → Allows namespace-level objects  
👉 `destinations` → Matching "expense-*" namespace is allowed

Apply the yaml file
```bash
kubectl apply -f AppProject.yml
```

## STEP 6️⃣ — ApplicationSet for Components with Notifications

Create an **ApplicationSet** to deploy all Expense microservice components (frontend, backend, database) per environment, with **component-specific notifications** and **sync waves**:

`ApplicationSet.yml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: expense-applicationset
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - env: dev
                #- env: stage
                #- env: prod
          - git:
              repoURL: https://github.com/my-org/my-repo.git
              revision: main
              directories:
                - path: cd/argocd/{{env}}/*
  template:
    metadata:
      name: expense-{{env}}-{{path.basename}}
      namespace: argocd
      labels:
        env: "{{env}}"
        project: expense
        component: "{{path.basename}}"

      annotations:
        # 🔹 SYNC WAVES (CRITICAL)
        argocd.argoproj.io/sync-wave: >
          {{- if eq path.basename "database" -}}0
          {{- else if eq path.basename "backend" -}}1
          {{- else if eq path.basename "frontend" -}}2
          {{- end }}

        # 🔹 Notifications
        notifications.argoproj.io/subscribe.on-deployed.email: "expense-{{env}}-{{path.basename}}@example.com"
        notifications.argoproj.io/subscribe.on-health-degraded.email: "expense-{{env}}-{{path.basename}}@example.com"
        notifications.argoproj.io/subscribe.on-sync-failed.email: "expense-{{env}}-{{path.basename}}@example.com"

    spec:
      project: expense-project

      source:
        repoURL: https://github.com/my-org/my-repo.git
        targetRevision: main
        path: "{{path}}/helm"
        helm:
          valueFiles:
            - values.yml

      destination:
        server: https://kubernetes.default.svc
        namespace: "expense-{{env}}"

      syncPolicy:
        automated:
          prune: true          # delete resources not in Git
          selfHeal: true       # revert out-of-band changes
        syncOptions:
          - CreateNamespace=true
          - ApplyOutOfSyncOnly=true
          - ServerSideApply=true
          - PruneLast=true
```
Apply the ApplicationSet:
```bash
kubectl apply -f expense-applicationset.yaml
```

---

### 👉 Explanation

👉 `matrix generator` → Combines **environments** (dev, stage, prod) with **Git directories** per component.  
👉 `name: expense-{{env}}-{{path.basename}}` → Generates application names like `expense-dev-frontend`.  
👉 `argocd.argoproj.io/sync-wave` → Ensures **database deploys first (0)**, then **backend (1)**, then **frontend (2)**.  
👉 `notifications.argoproj.io/subscribe.*.email` → Sends **component-specific email notifications**.  
👉 `syncPolicy` → Automates sync, self-heals, prunes resources not in Git.  
👉 `destination.namespace` → Creates environment-specific namespaces dynamically (`expense-dev`).  

👉 `metadata.annotations` → Component-specific notifications  
👉 `source.path` → Points to the Helm chart folder  
👉 `destination.namespace` → Isolated namespace per component  
👉 `syncPolicy` → Auto-sync, self-heal, auto-create namespace

✅ All triggers (on-deployed, on-health-degraded, on-sync-failed) are consistent with templates in ConfigMap.

## STEP 7️⃣ — Helm Charts for Each Component
Create **Helm charts** for each component (frontend, backend, database).  
Here’s an example for **expense-frontend**:

`expense-frontend/helm/Chart.yaml`
```yaml
apiVersion: v2
name: expense-frontend
version: 0.1.0
appVersion: "1.0.0"
type: application
```

Other components follow a similar Helm chart structure:

👉 `backend/helm/Chart.yaml`  
👉 `database/helm/Chart.yaml`

`expense-frontend/helm/values.yml`
```yaml
replicaCount: 2
image:
  repository: my-org/expense-frontend
  tag: "1.0.0"
service:
  type: ClusterIP
  port: 80
```
Other components follow a similar Helm chart structure:

👉 `backend/helm/values.yaml`  
👉 `database/helm/values.yaml`

templates/deployment.yaml & service.yaml → standard Kubernetes manifests
Repeat for backend and database. Database chart includes pvc.yaml.

## STEP 8️⃣ — Apply Everything

Apply all the resources to deploy the Expense microservice and configure notifications:

```bash
kubectl apply -f AppProject.yml
kubectl apply -f ApplicationSet.yml
kubectl apply -f argocd-notifications-cm.yaml
kubectl apply -f argocd-notifications-secret.yaml
kubectl rollout restart deployment argocd-notifications-controller -n argocd
```
## Explanation

👉 Apply `AppProject.yml` → Creates the Argo CD project for Expense microservice  
👉 Apply `ApplicationSet.yml` → Deploys frontend, backend, and database applications per environment  
👉 Apply `argocd-notifications-cm.yaml` → Configures notification templates and triggers  
👉 Apply `argocd-notifications-secret.yaml` → Provides SMTP credentials securely  
👉 Restart `argocd-notifications-controller` → Ensures the controller picks up the new Secret and ConfigMap


Check Applications: 
```bash
kubectl get applications -n argocd
```

Expected output (application names should match):
👉 expense-dev-frontend 
👉 expense-dev-backend 
👉 expense-dev-database

## STEP 9️⃣ — Testing

👉 Change `values.yml` (e.g., image tag) for any component  
👉 Push changes to Git  
👉 Argo CD ApplicationSet auto-syncs the updated component  
👉 Notifications controller sends email **only for that component**, using `on-deployed`, `on-sync-failed`, and `on-health-degraded` triggers







