# ARGO CD Deployment
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
