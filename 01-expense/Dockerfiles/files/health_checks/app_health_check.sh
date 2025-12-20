#!/usr/bin/env bash

# Exit non-zero if health endpoint fails
curl -fsSL localhost:8080/health

# -f → fail on HTTP errors
# -s → silent
# -S → show error if it fails
# -L → Follow redirects
