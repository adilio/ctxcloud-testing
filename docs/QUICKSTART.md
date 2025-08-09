# ctxcloud-testing — Quick Start

## Prerequisites
- **Terraform** 1.6.x or newer
- **AWS CLI v2** with configured credentials (`aws sts get-caller-identity` must succeed)
- IAM permissions to create/destroy **EC2**, **IAM**, and **S3** resources  
- SSH key pair in AWS region (only if you plan to SSH/RDP into instances)
- Recommended: run in a **dedicated non-production AWS account**

---

## Clone and Launch
```bash
git clone <your-repo-url>
cd ctxcloud-testing/code
chmod +x menu.sh
./menu.sh
```

---

## What the TUI Does
1. Runs preflight checks (Terraform, AWS CLI, AWS credentials, valid region)
2. Prompts to set `TF_VAR_region` (default `us-east-1`)
3. Detects your **public IP** and offers to set **SSH or RDP CIDR** to `<ip>/32` for secure access
   - Skipping will use scenario default (often `0.0.0.0/0`)
4. Auto-discovers all scenarios (by presence of `deploy.sh`)
5. Offers actions:
   - **🚀 Deploy**
   - **🗑️ Teardown**
   - **📄 View Info**
6. Logs actions to `./logs/<scenario>_<action>_<timestamp>.log`

---

## Example Interactive Flow
```bash
# Launch TUI
./menu.sh
# Select "linux-misconfig-web"
# Accept suggested SSH CIDR
# Deploy -> Validate -> Teardown
```

---

## Non-Interactive Usages
```bash
# List available scenarios
./menu.sh --scenarios

# Set variables for session
./menu.sh --set region ca-central-1
./menu.sh --set ssh_cidr 198.51.100.42/32
./menu.sh --set owner myteam

# Deploy a scenario
./menu.sh --run linux-misconfig-web deploy

# Tear it down
./menu.sh --run linux-misconfig-web teardown
```

**Pro Tip:**  
Chain `--run` commands in a script to simulate the **full 5-Act breach chain** automatically.

---

## Quick Validation Examples (linux-misconfig-web)
```bash
# Check open SSH/HTTP ports from your machine
nmap -Pn -p 22,80 <public_ip>

# Retrieve the canary file
curl http://<public_ip>/api_key.txt

# From EC2 instance: verify IMDSv1
curl -s http://169.254.169.254/latest/meta-data/

# Check EBS encryption flag
aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=<instance_id> --query 'Volumes[].Encrypted'
```

---

## Defaults & Overrides
- **Owner tag**: `aleghari`
- **Region**: `us-east-1`
- **HTTP/HTTPS**: open to all (`0.0.0.0/0`)
- **SSH/RDP**: restricted to chosen CIDR via TUI

**Override Defaults:**
```bash
./menu.sh --set owner yourname
./menu.sh --set region eu-west-1
./menu.sh --set ssh_cidr 203.0.113.7/32
```
Or edit [`common_vars.tf`](../common_vars.tf) directly.

---

## Cleanup
- Tear down a single scenario:
```bash
cd <scenario>
./teardown.sh
```

- Clean up **everything**:
```bash
./cleanup-all.sh
```

---

## Having Issues?
- **Invalid AWS credentials**: Run `aws configure`
- **Wrong region**: `./menu.sh --set region <region>`
- **SSH blocked**: Re-run TUI and accept detected `/32`
- **Check logs**: Inspect `./logs/` for full output and errors

---

## Next Steps
- Read [docs/ARCHITECTURE.md](ARCHITECTURE.md) for detailed scenario design and CNAPP mapping
- Explore each scenario’s README for purpose, misconfigs, and validation steps
