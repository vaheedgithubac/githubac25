## 1️⃣ Scenario  
Suppose you have a project called `myapp`, with:  
- Environments: `dev`, `staging`, `prod`  
- Components: `backend`, `frontend`  
**You want:**  
- Kubernetes resources labeled consistently  
- Easy grouping in Argo CD UI  

## 2️⃣ Example Deployment Template (Helm/Kustomize style)  
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "{{component}}-{{env}}"
  namespace: "{{env}}"
  labels:
    app.kubernetes.io/name: "{{component}}"           # Component name
    app.kubernetes.io/part-of: "{{project}}"          # Logical application/project
    app.kubernetes.io/instance: "{{component}}-{{env}}"  # Unique instance
    environment: "{{env}}"                             # Environment label
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: "{{component}}"
      app.kubernetes.io/part-of: "{{project}}"
  template:
    metadata:
      labels:
        app.kubernetes.io/name: "{{component}}"
        app.kubernetes.io/part-of: "{{project}}"
        environment: "{{env}}"
    spec:
      containers:
        - name: "{{component}}"
          image: "{{image}}:{{tag}}"
```
**How labels work:**
| Label                        | Example value (dev backend) | Purpose                                 |
| ---------------------------- | --------------------------- | --------------------------------------- |
| `app.kubernetes.io/name`     | `backend`                   | Identifies component name               |
| `app.kubernetes.io/part-of`  | `myapp`                     | Groups all resources of the application |
| `app.kubernetes.io/instance` | `backend-dev`               | Distinguishes individual instances      |
| `environment`                | `dev`                       | Environment-specific label              |

## 3️⃣ Argo CD Application YAML
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-backend-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp.git
    targetRevision: HEAD
    path: deployments/backend/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```
- Argo CD will `detect the resources` using the labels in the manifests. 
- You can search/filter by `app.kubernetes.io/part-of=myapp` in Argo CD UI to see **all resources belonging to** `myapp`, across components and environments.

## 4️⃣ Best practices
**1.** `app.kubernetes.io/part-of` = **application/project name**
    - Use **same value** for all components of the same app.   
**2.** `app.kubernetes.io/name` = **component/service name**
    - Backend, frontend, worker, etc.  
**3.** `app.kubernetes.io/instance` = **unique instance**  
    - Helps differentiate environments (dev vs prod).  
**4. Environment labels**  
   - Add `env: dev` or `environment: dev` for filtering in dashboards or Argo CD.  

## 5️⃣ Why this is helpful  
- **Argo CD UI grouping** You can see all resources with `part-of=myapp` together.  
- **RBAC / multi-project setup**: You can manage access by labels or Argo CD projects.  
- **Monitoring / dashboards**: Prometheus, Grafana, Lens, etc., can query by `part-of`.
