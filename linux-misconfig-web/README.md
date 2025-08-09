# 🌐 Linux Misconfig Web — CSPM/CDR/DSPM Misconfiguration Scenario

## 📌 Purpose
This scenario provisions a **misconfigured Linux-based web server** to test CSPM (Cloud Security Posture Management),  
CDR (Cloud Detection & Response), and DSPM (Data Security Posture Management) detections.  

In the **breach simulation narrative**, this is **Act III**:
1. **Act I (`iam-user-risk`)** — Attacker gains an overprivileged IAM identity.
2. **Act II (`dspm-data-generator`)** — Attacker identifies a rich dataset of sensitive information.
3. **Act III (`linux-misconfig-web`)** — Attacker compromises a Linux web server that *exposes sensitive data from Act II* through public endpoints.

---

## ⚠️ Misconfigurations
- Security group open to the world on HTTP (80) and SSH (22) — unless restricted via TUI.
- **Unencrypted root EBS** volume.
- **IMDSv1** enabled (`http_tokens = "optional"`).
- Running on **oldest Ubuntu 20.04 AMI** in the region.
- **Outdated packages** for higher vulnerability exposure.
- **Canary API Key** stored in `/var/www/html/api_key.txt` — simulates exposed secret.
- *(Enhance for narrative linkage)* Optionally fetches a file from DSPM scenario output directory and serves it under `/var/www/html/leaked_data.csv`.

---

## 🛠️ Deployment
From the repository root:

```bash
./menu.sh --run linux-misconfig-web deploy
```

---

## 🧹 Cleanup
From the repository root:

```bash
./menu.sh --run linux-misconfig-web teardown
```

---

## 🔍 Validation Steps

**Check exposed HTTP endpoint:**
```bash
curl http://<public-ip>/api_key.txt
```

**Confirm IMDSv1 is reachable:**
```bash
curl 169.254.169.254/latest/meta-data/
```

**Check if leaked DSPM dataset is served (if enabled):**
```bash
curl http://<public-ip>/leaked_data.csv
```

---

## 🗡️ Narrative Link
In the **lab breach storyline**, by the time the attacker reaches this stage:
- They *already* have IAM credentials from Act I.
- They *already* know sensitive data exists from Act II.
- Here, they find a misconfigured Linux web app that **publicly serves sensitive data**, blending CSPM and DSPM risks into a single exploit.

This directly builds tension for **Act IV — `windows-vuln-iis`**, which mirrors this in a Windows environment.
