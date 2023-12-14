#!/bin/bash

export RENOVATE_CONFIG_FILE="/home/steven/Projects/mojaloop/helm/renovate/config.js"
export RENOVATE_TOKEN="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" # GitHub, GitLab, Azure DevOps
export GITHUB_COM_TOKEN="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" # Delete this if using github.com

# Renovate
renovate --onboarding=false --dry-run=full