# Usage: <script_name>.sh <GITHUB_USERNAME> <GITHUB_TOKEN> <REPO_NAME> <IMAGE_NAME> <DEPLOYMENT_FILE> <BRANCH>

#!/usr/bin/env bash

set -e

# === INPUTS ===
GITHUB_USERNAME="$1"
GITHUB_TOKEN="$2"
REPO_NAME="$3"
IMAGE_NAME="$4"                # e.g., your-registry/your-image
DEPLOYMENT_FILE="$5"           # e.g., k8s/deployment.yaml
BRANCH="${6:-main}"            # Optional: defaults to main

# === VALIDATION ===
if [[ -z "$GITHUB_USERNAME" || -z "$GITHUB_TOKEN" || -z "$REPO_NAME" || -z "$IMAGE_NAME" || -z "$DEPLOYMENT_FILE" ]]; then
  echo "Usage: $0 <github-username> <github-token> <repo-name> <image-name> <deployment-file> [branch]"
  exit 1
fi

# === GIT CONFIG ===
git config user.name "$GITHUB_USERNAME"
git config user.email "$GITHUB_USERNAME@users.noreply.github.com"

# === ENSURE CLEAN WORKSPACE ===
git checkout "$BRANCH"
git pull origin "$BRANCH"

# === GET COMMIT HASH ===
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "Using commit hash: $COMMIT_HASH"

# === UPDATE DEPLOYMENT FILE ===
echo "Updating $DEPLOYMENT_FILE to use image tag: $COMMIT_HASH"
# sed -i.bak -E "s|(${IMAGE_NAME}:)[a-zA-Z0-9._-]+|\1${COMMIT_HASH}|" "$DEPLOYMENT_FILE"
sed -i "s#image: ${IMAGE_NAME}:.*#image: ${IMAGE_NAME}:${COMMIT_HASH}#" "$DEPLOYMENT_FILE"

# === COMMIT AND PUSH ===
git add "$DEPLOYMENT_FILE"
git commit -m "chore: update image tag to $COMMIT_HASH"
git push "https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git" "$BRANCH"

echo "✅ Deployment file updated and pushed to $BRANCH"
