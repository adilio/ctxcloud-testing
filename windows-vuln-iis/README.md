# 🖥️ Windows Vuln IIS — CSPM/CDR/DSPM Misconfiguration Scenario

## 📌 Purpose
This scenario provisions a **misconfigured Windows Server running IIS** to test CSPM (Cloud Security Posture Management),  
CDR (Cloud Detection & Response), and DSPM (Data Security Posture Management) detections.  

In the **breach simulation narrative**, this is **Act IV**:
1. **Act I (`iam-user-risk`)** — Attacker gains an overprivileged IAM identity.
2. **Act II (`dspm-data-generator`)** — Attacker identifies a rich dataset of sensitive information.
3. **Act III (`linux-misconfig-web`)** — Attacker compromises a Linux web server exposing the data.
4. **Act IV (`windows-vuln-iis`)** — Attacker pivots to a Windows workload, replicating similar risks in a new platform.

---

## ⚠️ Misconfigurations
- Public RDP access on port 3389 (unless restricted via variable).
- **Unencrypted root volume** (EBS).
- **IMDSv1** enabled (`http_tokens = "optional"`).
- Running on **oldest available Windows Server 2019 AMI** in the region.
- IIS with **directory browsing enabled**.
- Canary file `canary.txt` in `C:\inetpub\wwwroot\` simulating an exposed secret.
- Optional simulated link to DSPM leaked dataset (`dspm_leak.csv`).

---

## 🛠️ Deployment
From the repository root:

```bash
./menu.sh --run windows-vuln-iis deploy
```

---

## 🧹 Cleanup
From the repository root:

```bash
./menu.sh --run windows-vuln-iis teardown
```

---

## 🔍 Validation Steps

**Check public RDP access:**
```bash
nmap -Pn -p 3389 <public-ip>
```

**Connect via RDP (use appropriate client):**
```bash
xfreerdp /u:Administrator /p:<password> /v:<public-ip>
```

**Browse IIS site for canary file:**
```bash
curl http://<public-ip>/canary.txt
```

**Check directory browsing:**
```bash
curl http://<public-ip>/
```

**Fetch DSPM leak if configured:**
```bash
curl http://<public-ip>/dspm_leak.csv
```

---

## 🗡️ Narrative Link
In the storyline, the attacker has already demonstrated capability by compromising Linux infrastructure.  
Now, they exploit similar weaknesses in Windows, showing multi-platform reach and linking to sensitive DSPM data for maximum impact.  

This sets the stage for **Act V — `docker-container-host`**, where the attacker pivots into container exploitation.