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


STEP 0️⃣ — Assumptions

👉 Kubernetes cluster exists
👉 Argo CD is installed in the argocd namespace
👉 You have access to a Git repository
👉 You have SMTP credentials to send emails
👉 We will configure the Argo CD Notifications controller using a Kubernetes Secret for email credentials
