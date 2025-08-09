# 🔐 IAM User Risk — CIEM Misconfiguration Scenario

## 📌 Purpose
This scenario demonstrates **Cloud Infrastructure Entitlement Management (CIEM)** misconfigurations that create high-impact identity risks within AWS.  
It simulates a dangerously overprivileged IAM identity, forming the foundation for the lab's breach storyline.

## ⚠️ Misconfigurations
- IAM user **with no MFA enabled**
- Two **simultaneous active access keys**
- **Broad inline IAM policy** granting full administrative privileges
- *(Optional)* Weak account password policy (allows short, simple passwords)

## 🛠️ Deployment
From the repository root:

```bash
./menu.sh --run iam-user-risk deploy
```

## 🧹 Cleanup
From the repository root:

```bash
./menu.sh --run iam-user-risk teardown
```

This will remove access keys first, then delete the IAM user.

## 🔍 Validation Steps
Use the AWS CLI to confirm misconfigurations after deployment:

**List IAM users:**
```bash
aws iam list-users
```

**Check MFA devices:**
```bash
aws iam list-mfa-devices --user-name iam-lab-user
```

**List access keys:**
```bash
aws iam list-access-keys --user-name iam-lab-user
```

**Inspect inline policies:**
```bash
aws iam list-user-policies --user-name iam-lab-user
aws iam get-user-policy --user-name iam-lab-user --policy-name iam-lab-user-broad-policy
```

## 🗡️ Narrative Link
In the **lab storyline**, this compromised IAM identity is the attacker's **first foothold** — the "villain's key" that opens doors to further mischief.  
With this access, the attacker can enumerate resources, discover sensitive data, and prepare for lateral movement in subsequent scenarios.