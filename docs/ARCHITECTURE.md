# ctxcloud-testing — Architecture

## Goal
A modular AWS lab, built with **Terraform + Bash only**, that triggers common CNAPP detections (CSPM, CDR, CIEM, DSPM, CWPP) quickly and safely. Designed for a clean UX for both humans and automation.

---

## Principles
- **One scenario per self-contained folder** (Terraform + scripts + README)
- Small, high-signal misconfigs (3–5 each act)
- **Bash TUI** as the single entry point (no manual tfvars editing needed)
- Safe defaults, quick teardown
- Default owner: `aleghari`
- Default region: `us-east-1`
- HTTP/HTTPS left open for demo; SSH/RDP can be restricted via TUI prompt

---

## Repository Layout
```
ctxcloud-testing/
├── menu.sh                     # Interactive TUI for scenario deploy/teardown/info
├── cleanup-all.sh              # Tears down all scenarios
├── common_vars.tf              # Shared Terraform variables across scenarios
├── lib/
│   └── checks.sh               # Preflight checks for Terraform, AWS CLI, and credentials
├── docs/
│   ├── ARCHITECTURE.md         # This file
│   └── QUICKSTART.md           # New user setup guide
├── linux-misconfig-web/        # Act III
│   ├── main.tf                 # Deploys outdated Ubuntu, public SG, IMDSv1, unencrypted EBS
│   ├── vars.tf                 # Scenario-specific input variables
│   ├── outputs.tf              # IP/DNS/SG outputs
│   ├── user_data.sh            # Installs outdated packages, Nginx dir listing, canary key
│   ├── deploy.sh               # Preflight, init, validate, apply
│   ├── teardown.sh              # Destroy infrastructure
│   └── README.md               # Scenario overview and validation steps
├── windows-vuln-iis/           # Act IV
│   ├── main.tf                 # Deploys older Windows AMI, public RDP SG, IMDSv1
│   ├── vars.tf                 # Scenario variables (owner, region, allow_rdp_cidr)
│   ├── user_data.ps1            # Enables IIS dir browsing, places canary in web root
│   ├── deploy.sh               # Deploy script
│   ├── teardown.sh             # Teardown script
│   └── README.md               # Scenario overview and tests
├── docker-container-host/      # Act V
│   ├── main.tf                 # EC2 with Docker, SG 8080, IMDSv1, risky mount
│   ├── vars.tf                 # Variables incl. SSH key path, CIDRs
│   ├── user_data.sh            # Runs root container, host networking/mount
│   ├── deploy.sh               # Deploy script with validate and apply
│   ├── teardown.sh             # Teardown script
│   └── README.md               # Scenario overview
├── iam-user-risk/              # Act I
│   ├── main.tf                 # Create overly permissive IAM user
│   ├── deploy.sh               # Deploy
│   ├── teardown.sh             # Teardown
│   └── README.md               # Scenario description
├── dspm-data-generator/        # Act II
│   ├── dspm-data-generator.sh  # Generates fake PII, PCI, PHI, secrets
│   ├── dspm-upload-to-s3.sh    # Uploads fake data to S3 (optional public)
│   └── README.md               # Usage and validation
```

---

## TUI Design (menu.sh)
Purpose: Be the **single command UX**.

### Flow
1. **Checks**: Source `lib/checks.sh`, verify Terraform, AWS CLI, credentials, and region.
2. **Region**: Default `us-east-1`, configurable.
3. **SSH/RDP CIDR**: Auto-detect public IP, offer `<ip>/32`.
4. **Discovery**: Find scenarios by detecting `deploy.sh`.
5. **Selection**: Choose deploy, teardown, or view info.
6. **Logging**: Write logs per action to `logs/`.

### Non-interactive
```
./menu.sh --run linux-misconfig-web deploy
./menu.sh --run linux-misconfig-web teardown
./menu.sh --set region eu-west-1
./menu.sh --set ssh_cidr 198.51.100.42/32
```

---

## Scenario Pattern
Each scenario contains:
- `main.tf` — Terraform infrastructure definition
- `vars.tf` — Variables (owner, region, CIDRs, etc.)
- `user_data.*` — Bootstraps misconfigurations or vulnerabilities
- `deploy.sh` — Runs preflight checks, `terraform init`, validate, then apply
- `teardown.sh` — Destroys resources
- `README.md` — Purpose, misconfig list, validation steps
- Optional `outputs.tf`

**Tagging Standard**
```hcl
tags = {
  owner    = var.owner
  scenario = var.lab_scenario
}
```

---

## Misconfiguration Coverage

### Act I — iam-user-risk
- No MFA
- Two active access keys
- Broad inline policy

### Act II — dspm-data-generator
- Generate fake sensitive data
- Optional public S3 bucket hosting

### Act III — linux-misconfig-web
- IMDSv1 allowed
- Public HTTP/S and SSH (CIDR restricted by TUI if desired)
- Unencrypted EBS root volume
- Oldest Ubuntu 20.04 AMI
- Outdated packages
- World-readable canary token in webroot
- Directory browsing enabled

### Act IV — windows-vuln-iis
- Public RDP / CIDR-restricted
- IMDSv1 allowed
- Unencrypted EBS
- IIS directory browsing enabled
- Canary file in webroot

### Act V — docker-container-host
- Root container user
- Host networking
- Host `/etc` mount
- IMDSv1 accessible

---

## Safety & Cost
- Minimal resource footprint per deployment
- Always clean up:
  - Per scenario: `./teardown.sh`
  - All resources: `./cleanup-all.sh`
- Use non-production AWS accounts

---

## Troubleshooting
- AWS CLI credentials must be valid
- Wrong region? Use `./menu.sh --set region <region>`
- SSH blocked? Accept detected `/32` in TUI
- Logs: `./logs/` contains full action output

# 📐 Architecture — Updated for Deployment Flow Changes

## 🛠️ Deployment Behavior
- **Dedicated VPC + Subnet Creation:** All EC2-based scenarios now provision their own isolated VPC and public subnet, removing reliance on AWS default VPCs.
- **EC2 Subnet Association:** EC2 resources explicitly launch in the scenario-created subnet to ensure compatibility even in accounts without a default VPC.
- **Scenario State Preservation:** `.terraform/` and `terraform.tfstate` are preserved between runs, avoiding unintended destroy/redeploy cycles.
- **Dynamic SSH CIDR Prompting:** Non-EC2 scenarios (e.g., IAM-only, DSPM data creation) skip the SSH CIDR prompt for a cleaner workflow.
- **Public IP/DNS Output Clarity:** When a scenario has no EC2 instance, outputs display "Not applicable" instead of `N/A` to reduce confusion.

## 📂 Structural Adjustments
- Removed all references to `blueprint.md` from public documentation.
- Added executable `deploy.sh` to `dspm-data-generator` for proper detection in `menu.sh` scenario ordering.

## ⚠️ Security Notice
These changes keep scenarios intentionally insecure—for CNAPP detection and training—while improving stability, clarity, and usability.
