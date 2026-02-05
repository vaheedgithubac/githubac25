## How to download ECR Private Repo image in Kubernetes
✅ This is the **BEST and recommended approach** for EKS + ECR.  
1️⃣ What IRSA solves (big picture)

**Problem without IRSA:**
  - You create ECR secrets
  - Tokens expire every 12 hours
  - You must rotate them        

**IRSA solution:**
  - No Docker secrets
  - No tokens
  - No rotation
  - Pods automatically authenticate to ECR using AWS IAM
`Kubernetes → AWS IAM → ECR (secure & automatic)`

## 2️⃣ How IRSA works (mental model)  
```text
Pod
 └─ ServiceAccount
     └─ IAM Role (via OIDC)
         └─ ECR permissions
```
- Pod uses a Kubernetes ServiceAccount
- ServiceAccount is linked to an IAM Role
- AWS allows that role to pull images from ECR

## 3️⃣ Prerequisites
**You must have:**  
✔ EKS cluster  
✔ AWS CLI configured  
✔ `eksctl` installed  
✔ ECR repository exists  

## 4️⃣ Enable OIDC provider (one-time)
Create IAM OIDC privider
```bash
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --region us-east-1 \
  --approve
```
✔ This allows EKS to use IAM roles with ServiceAccounts

### 5️⃣ Create IAM policy for ECR access  
Create a file `ecr-policy.json`:
```text
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    }
  ]
}
```
Create the policy:
```bash
aws iam create-policy \
  --policy-name EKS-ECR-Pull-Policy \
  --policy-document file://ecr-policy.json
```
### 6️⃣ Create IAM Role + ServiceAccount (IRSA) 
This command does everything:
  - Creates IAM Role
  - Attaches ECR policy
  - Creates Kubernetes ServiceAccount
  - Links them together

```bash
eksctl create iamserviceaccount \
  --cluster my-cluster \
  --region us-east-1 \
  --namespace app \
  --name ecr-sa \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/EKS-ECR-Pull-Policy \
  --approve
```
✅ Result:
  - IAM Role created
  - ServiceAccount `ecr-sa` created in `app` namespace  

### 7️⃣ Use the ServiceAccount in your Deployment  
`Deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      serviceAccountName: ecr-sa
      containers:
      - name: app
        image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
```
🚨 Important:  
  ❌ NO imagePullSecrets  
  ❌ NO Docker secret  
  ✔ IRSA handles auth  

## 8️⃣ What happens at runtime (flow)  
**1. Pod starts**  
**2. Kubelet requests image from ECR**  
**3. AWS checks IAM role via OIDC**  
**4. Role has ECR permissions**  
**5. Image is pulled**  
**6. Pod runs**  

## 9️⃣ How to verify IRSA is working 
**Check ServiceAccount annotation**
```bash
kubectl get sa ecr-sa -n app -o yaml
```  
You should see:   
```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/eksctl-...
```
**Check pod events**
```bash
kubectl describe pod <pod-name> -n app
```
If working:
  - ❌ No ImagePullBackOff
  - ❌ No auth errors

## 🔟 Common mistakes (VERY common)

❌ Forgetting to use the ServiceAccount in Deployment  
❌ Wrong namespace  
❌ Missing OIDC provider  
❌ Using node IAM role instead (old method)  
❌ ECR repo in different region  

## 1️⃣1️⃣ Comparison (why IRSA wins)
| Method        | Secrets | Rotation | Security | Recommended |
| ------------- | ------- | -------- | -------- | ----------- |
| Docker secret | Yes     | Manual   | ⚠️       | ❌           |
| Cron refresh  | Yes     | Auto     | ⚠️       | ⚠️          |
| Node IAM role | No      | Auto     | ⚠️       | ❌           |
| **IRSA**      | **No**  | **Auto** | **✅**    | **⭐⭐⭐**     |  

🧠 Final takeaway  
**If you are using EKS + ECR → always use IRSA**  
**It is:**
 - Secure
 - Simple
 - Production-grade
 - GitOps-friendly
 - Zero secrets










