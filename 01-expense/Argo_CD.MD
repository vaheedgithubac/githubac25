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
  smtp-host: smtp.gmail.com
  smtp-port: 465                 #"465"
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

## STEP 5️⃣ — AppProject Creation

Create an **AppProject** in `argocd` namespace to group and manage all **expense** microservice applications, define allowed Git repos, destinations, and roles:
**AppProject** for non-prod environments like(dev, stage)  
`AppProject.yml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject                                # This will be used to group 'Applications' under this Project
metadata:
  name: expense-project-dev
  namespace: argocd
spec:
  description: Project for expense microservice

  sourceRepos:
    - "https://github.com/my-org/expense.git"   # Argo CD 'Applications' which are part of this Project can only deploy from this repository

  destinations:
    - namespace: "expense-dev"                  # This Project will allow to deploy only on "expense-dev" namespaces
      server: https://kubernetes.default.svc    # This Project will allow to deploy only on this kubernetes cluster

    - namespace: "expense-stage"                # This Project will allow to deploy only on "expense-dev" namespaces
      server: https://kubernetes.default.svc    # This Project will allow to deploy only on this kubernetes cluster

  clusterResourceWhitelist:
    - group: ""
      kind: "Namespace"                         # This Project will allow child Apps to create Namespace

  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"
```
### Explanation

👉 `clusterResourceWhitelist` → Allows Helm charts to deploy cluster level resources like Namespace, ClusterRole, CRB, PV, SC, CRDs, etc.  
👉 `namespaceResourceWhitelist` → Allows namespace-level objects  
👉 `destinations` → Matching "expense-(dev/stage)" namespace is allowed

Apply the yaml file
```bash
kubectl apply -f AppProject.yml
```

## STEP 6️⃣ — ApplicationSet for Components with Notifications

Create an **ApplicationSet** to deploy all **expense** microservice components (frontend, backend, database) per environment, with **component-specific notifications** and **sync waves**:

`ApplicationSet.yml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: expense-applicationset-dev
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
      project: expense-project-dev         # This is the name of 'AppProject' created previously

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

👉 `metadata.annotations` → Component-specific notifications  
👉 `source.path` → Points to the Helm chart folder  
👉 `destination.namespace` → Isolated namespace per component, Creates environment-specific namespaces dynamically (`expense-dev`).   
👉 `syncPolicy` → Auto-sync, self-heal, auto-create namespace and prunes resources not in Git.

✅ All triggers (on-deployed, on-health-degraded, on-sync-failed) are consistent with templates in ConfigMap.

## STEP 7️⃣ — Helm Charts for Each Component
Create **Helm charts** for each component (frontend, backend, database).  
Here’s an example for **expense-frontend**:

`frontend/helm/Chart.yaml`
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

`frontend/helm/values.yml`
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

## STEP 🔟 — Create Users and Assign Roles in Argo CD (RBAC)

Argo CD user access is controlled using **RBAC**, configured via: following **ConfigMaps** in the namespace:`argocd` 

- `argocd-cm` → Defines users  
- `argocd-rbac-cm` → Maps users to roles

## 🔹 STEP 10.1 — Create Users `(argocd-cm)`

Edit or create the ConfigMap `argocd-cm` in the `argocd` namespace

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  application.namespaces: argocd      # Ensures Application related CRs in 'argocd' namespace for best practice and security

  accounts.expense-dev-user: login
  accounts.expense-stage-user: login
  accounts.expense-prod-user: login
  accounts.expense-admin: login
```

## Explanation
👉 `accounts.<username>: login` → Creates a local Argo CD user   
👉 These users can authenticate via username/password    
👉 Passwords will be set separately (next step)   

## 🔹 STEP 10.2 — Set Passwords for Users  
Use the Argo CD CLI to set passwords.  

```bash
argocd account update-password --account expense-dev-user  
argocd account update-password --account expense-stage-user   
argocd account update-password --account expense-prod-user
argocd account update-password --account expense-admin  
```
👉 You will be prompted to enter passwords interactively.   

## 🔹 STEP 10.3 — Map Users to Project Roles `(argocd-rbac-cm)` 
Now bind users to the AppProject roles you already created `(expense-project)` **in step:5**.   
Create or update `argocd-rbac-cm`:
```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly    # Default role for the user that is not associated with any

  policy.csv: |
    # expense Dev + Stage user
    p, role:expense-dev, applications, *, expense-dev/*, allow
    p, role:expense-stage, applications, *, expense-stage/*, allow

    # expense Prod user
    p, role:expense-prod, applications, *, expense-prod/*, allow

    # expense Admin (FULL)
    p, role:expense-admin, *, *, expense-dev/*, allow
    p, role:expense-admin, *, *, expense-stage/*, allow
    p, role:expense-admin, *, *, expense-prod/*, allow

    # Bind users to appropriate roles
    g, expense-dev-user, role:expense-dev
    g, expense-stage-user, role:expense-stage
    g, expense-prod-user, role:expense-prod
    g, expense-admin-user, role:expense-admin
```   

## Explanation
```bash
syntax:  p, <subject>, <resource>, <action>, <object>, <effect>
example: p, role:expense-nonprod, applications, *, expense-dev/*, allow   
```
| Field                  | Value    | Meaning                                    |
| ---------------------- | -------- | ------------------------------------------ |
| `p`                    | policy   | This is a permission rule                  |
| `role:expense-nonprod` | subject  | The RBAC role                              |
| `applications`         | resource | Argo CD Application objects                |
| `*`                    | action   | Any action (get, list, sync, delete, etc.) |
| `expense-dev/*`        | object   | **project/application-name**               |
| `allow`                | effect   | Permit access                              |

```text
syntax:   g, <subject>, <role>
example:  g, expense-dev-user, role:expense-nonprod
```
| Part                   | Value         | Meaning            |
| ---------------------- | ------------- | ------------------ |
| `g`                    | grouping rule | Assign membership  |
| `expense-dev-user`     | subject       | A **user account** |
| `role:expense-nonprod` | role          | The RBAC role      |

```bash
argocd account get-user-info

Logged In: true
Roles: <role>   # admin
```


## 🔹 STEP 10.4 — Restart Argo CD Server  
RBAC changes require restarting the Argo CD server.   
```bash
kubectl rollout restart deployment argocd-server -n argocd   
```
## 🔹 STEP 10.5 — Validate Access
Login as `expense-frontend-user`   
```bash
argocd login <ARGOCD_SERVER> --username expense-frontend-user
argocd app list   
```
Expected behavior:   
👉 `expense-dev-user`    
    ✔ Can manage only `expense-dev` namespace objects tied to `AppProject: expense-dev` 
👉 `expense-stage-user`   
    ✔ Can manage only `expense-stage` namespace objects tied to `AppProject: expense-stage` 
👉 `expense-prod-user`   
    ✔ Can manage only `expense-prod` namespace objects tied to `AppProject: expense-prod`
👉 `expense-admin-user`   
    ✔ Full access to all Expense applications    

## 🔐 Final Access Summary      

| User                  | Role            | Access Scope                          |   
| --------------------- | --------------- | ------------------------------------  |    
| expense-dev-user      | expense-dev     | `expense-dev` namespace apps only     |   
| expense-stage-user    | expense-stage   | `expense-stage` namespace apps only   |    
| expense-prod-user     | expense-prod    | `expense-prod` namespace apps only    |  
| expense-admin         | expense-admin   | Full Expense access                   |   

## To know currently loggedin user info:
```bash
argocd account get-user-info
```
```text
Logged In: true
Username: admin
Roles: admin
Groups: 
```
## STEP 1️⃣1️⃣ — Use Private Git Repository with Argo CD       
✅ **Method 1 — SSH Authentication (Recommended)**   
## 🔹 STEP 11.1.1 — Generate SSH Key (if you don’t have one) 
```bash
ssh-keygen -t ed25519 -C "argocd@git"
```
This creates:    
- Private key → `~/.ssh/id_ed25519`    
- Public key → `~/.ssh/id_ed25519.pub`

## STEP 11.1.2 — Add Public Key to Git Provider
Example: GitHub   

1. Go to Repo → Settings → Deploy keys   
2. Click Add deploy key    
3. Paste contents of `id_ed25519.pub`    
4. Enable Read-only access   
5. Save    
👉 This allows Argo CD to read the repo securely.   

## 🔹 STEP 11.1.3 — Add Private Repo to Argo CD   
Use the Argo CD CLI:   
```bash
argocd repo add git@github.com:my-org/my-repo.git \
  --ssh-private-key-path ~/.ssh/id_ed25519
```
✔ Argo CD stores the key securely as a Kubernetes Secret   
✔ No plaintext passwords in Git   
✔ Works with Application & ApplicationSet   

## 🔹 STEP 11.1.4 — Verify Repository Access  
```bash
argocd repo list
```
Expected:   
```text
TYPE  NAME                                 STATUS
git   git@github.com:my-org/my-repo.git   Successful
```
- Why SSH is Best   
👉 No passwords stored   
👉 Read-only deploy keys   
👉 Works with GitHub, GitLab, Bitbucket   
👉 Secure and production-proven   

✅ **Method 2 — HTTPS Authentication (Username + Token)**   
## 🔹 STEP 11.2.1 —— Create a Git Token   
Example: GitHub
- Settings → Developer settings → Personal access tokens
- Scope: `repo` (read-only is sufficient)

## 🔹 STEP 11.2.1 —— Add Repo Using HTTPS
```bash
argocd repo add https://github.com/my-org/my-repo.git \
  --username <git-username> \
  --password <git-token>
```  
👉 Token is stored securely as a Secret   
👉 Works well but **less secure than SSH**   

🔐 Where Credentials Are Stored   
Argo CD stores repo credentials as Kubernetes Secrets:   
```bash
kubectl get secrets -n argocd | grep repo
```
Example:   
```text
argocd-repo-creds-xxxx
```
👉 Secrets are **encrypted at rest** (if K8s encryption is enabled)   
👉 Not exposed in Applications or Git   

🔁 Using Private Repo with ApplicationSet
Once the repo is added, no change is required in your manifests:
```yaml
repoURL: git@github.com:my-org/my-repo.git
```
Argo CD automatically uses stored credentials.


## 🔹🔹 Bonus: Namespace (protected)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: expense
  annotations:
    argocd.argoproj.io/sync-options: Prune=false   
```
Kubernetes will not allow to delete the above namespace `expense` by 'Argo CD'










