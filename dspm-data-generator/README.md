# 📂 DSPM Data Generator — Sensitive Data Simulation

## 📌 Purpose
This scenario creates **realistic-looking sensitive data** to simulate **Data Security Posture Management (DSPM)** detections.  
It supports multiple data types (PII, PCI, PHI, secrets, mixed) and can optionally upload generated data to AWS S3 — either privately or publicly.

In our **lab storyline**, this represents the “treasure chest” attackers seek after gaining identity access in **Act I (`iam-user-risk`)**, setting up the stakes for later infrastructure compromises.

---

## ⚠️ Data Profiles
The generator can produce:
- **PHI** (Personal Health Information)
- **PII** (Personally Identifiable Information)
- **PCI** (Payment Card Industry data)
- **Secrets** (API keys, tokens, credentials)
- **Financial** records
- **Mixed** — blended sensitive attributes to challenge data detection tooling

---

## 🛠️ Deployment
From the repository root:

```bash
./menu.sh --run dspm-data-generator deploy
```

Or invoke the generator directly:

```bash
cd dspm-data-generator
./dspm-data-generator.sh
```

---

## 🧹 Cleanup
Locally generated datasets remain in the output directory (`dspm_test_data` by default).  
If uploaded to S3, use:

```bash
aws s3 rm s3://<bucket-name> --recursive
aws s3 rb s3://<bucket-name> --force
```

---

## 🔍 Validation Steps

**List generated CSV files:**
```bash
ls dspm_test_data/
```

**Preview sensitive data patterns:**
```bash
head dspm_test_data/*.csv
```

**If public S3 upload:**
```bash
curl https://<bucket-name>.s3.<region>.amazonaws.com/<path-to-object>
```

---

## 🗡️ Narrative Link
In the **breach simulation narrative**:
1. **Act I (`iam-user-risk`)** — Attacker gains overprivileged IAM credentials.
2. **Act II (`dspm-data-generator`)** — Attacker discovers a treasure trove of sensitive data.
3. **Act III onward** — Attacker pivots to misconfigured workloads that can serve, expose, or move this data.
