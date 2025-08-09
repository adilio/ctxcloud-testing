# Docker Container Host — CWPP / CSPM / Breach Simulation Act V

## 🎯 Purpose  
This scenario demonstrates **container and host exploitation risks** in a cloud environment, showing how weak container configurations can amplify exposure when chained with IAM, DSPM, and CSPM gaps from earlier acts.

It deploys an **Ubuntu EC2 instance** running Docker with a deliberately risky container setup:
- Root container user
- Host network mode
- Mounts host `/etc` into container (read-only)
- IMDSv1 enabled for instance metadata theft
- Publicly accessible web application on port 8080
- Optional DSPM leak file

---

## 🛠️ Misconfigurations in this Scenario
- **CWPP**: Container runs as root, risky volume mounts, host networking.
- **CSPM**: Public security group for SSH and app port.
- **DSPM link**: Sensitivity token file stored on host, potentially accessible from container or app.
- **Other risk**: Unencrypted root EBS volume.

---

## 🚀 Deployment

```bash
cd code/docker-container-host
./deploy.sh
```

---

## 🔍 Validation Steps
1. Confirm EC2 instance is accessible on port 8080:
   ```bash
   curl http://<PUBLIC_IP>:8080
   ```
2. SSH into instance and inspect container:
   ```bash
   ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>
   docker exec -it risky-container bash
   cat /host-etc/passwd
   ```
3. Retrieve IMDSv1 metadata tokens:
   ```bash
   curl http://169.254.169.254/latest/meta-data/
   ```

---

## 🧹 Teardown
```bash
cd code/docker-container-host
./teardown.sh
```

---

## 📖 Narrative Link
- **Previous Act**: [`windows-vuln-iis`](../windows-vuln-iis/README.md) — Showed Windows/IIS platform misconfigs.
- **This Act**: Demonstrates **CWPP risks** from containers, combining:
  - IAM exposures (Act I)
  - DSPM leaks (Act II)
  - Linux host misconfig (Act III)
  - Windows host misconfig (Act IV)
  - Container-level exploitation (Act V)
- **Outcome**: Blueprints a **multi-surface breach path** from identity to data theft, infrastructure abuse, and container compromise.