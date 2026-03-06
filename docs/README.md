# vault-otp-ui AMI Build and Deployment

Packer templates and GitHub Actions for building an AWS AMI that runs the vault-otp-ui application. The AMI is based on the Ubuntu golden image (or Canonical Ubuntu) and includes Docker, docker compose, the application files in `/opt/vault-otp-ui`, and a systemd service that runs docker compose on boot.

## Default: ALB + ACM

TLS is terminated at the AWS Application Load Balancer. The instance serves HTTP on port 8080. No in-container TLS by default. ACM handles certificate renewal. Configure ALB listeners (80 redirect to 443, 443 forward to target group HTTP:8080), ACM certificate with SAN for both hostnames, and DNS records for `vault-otp-ui.medneo.com` and `vault-otp-ui.beyond-imaging.com`.

## Implementation Summary

**GitHub Actions.** CI runs `packer fmt -check` and `packer validate` on PRs. The AMI build workflow runs on merge to main/master, on push of a `release-*` tag, or when triggered manually (Actions tab, "Build AMI", Run workflow). Uses OIDC for AWS (no long-lived keys). AMI ID is printed in the workflow summary.

**AWS AMI build.** Base AMI from `source_ami_filter` matching golden-images-base-os conventions: name pattern `ubuntu-base-*-prod-*`, tags `OS=ubuntu`, `Environment=prod`, `most_recent = true`. Canonical fallback uses `ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*`. Provisioning installs Docker + compose, copies app assets to `/opt/vault-otp-ui`, loads Docker images from tar (required), enables systemd service.

**Health check.** The nginx sidecar serves `/healthz` with HTTP 200 on port 8080. ALB target group must use path `/healthz`.

**Optional local TLS.** `docker-compose-tls-override.yml` adds Caddy with Let's Encrypt for both hostnames. Persists ACME state in volume `tls_certs_caddy`. Requires `ACME_EMAIL` env. Only for direct-instance TLS when ALB termination is not used.

**Legacy.** `docker-compose-tls.yml` (hitch-based) is deprecated for AWS. Kept only for vSphere. Use ALB + ACM for AWS.

## Architecture

- **Default (AWS)**: HTTP on 8080, ALB terminates TLS. Health endpoint: `/healthz`.
- **Optional**: Local TLS via `docker-compose-tls-override.yml` (Caddy + Let's Encrypt).
- **Hostnames**: `vault-otp-ui.medneo.com`, `vault-otp-ui.beyond-imaging.com`

## Local Packer Build

### Prerequisites

- Packer >= 1.9.0
- AWS credentials (profile or env vars)
- Docker (for pre-pulling images into the AMI)

### Build with Canonical Ubuntu base AMI

Requires `docker_images_tar_path` pointing to a valid tar of vault-otp-ui and nginx:alpine:

```bash
# From repo root
docker pull medneo-docker.jfrog.io/vault-otp-ui:1.0.0
docker pull nginx:alpine
docker save -o docker-images.tar medneo-docker.jfrog.io/vault-otp-ui:1.0.0 nginx:alpine

packer init packer/aws/
packer build \
  -var "artifact_identifier=$(git rev-parse --short HEAD)" \
  -var "aws_region=eu-central-1" \
  -var "aws_source_ami_owner=099720109477" \
  -var "use_golden_image_filter=false" \
  -var "base_ami_ubuntu_version=22.04" \
  -var "docker_images_tar_path=./docker-images.tar" \
  packer/aws/
```

### Build with golden image base AMI

Requires a golden image `ubuntu-base-*-prod-*` with tags `OS=ubuntu`, `Environment=prod`:

```bash
packer build \
  -var "artifact_identifier=$(git rev-parse --short HEAD)" \
  -var "aws_region=eu-central-1" \
  -var "aws_source_ami_owner=YOUR_AWS_ACCOUNT_ID" \
  -var "use_golden_image_filter=true" \
  -var "base_ami_name_pattern=ubuntu-base-*-prod-*" \
  -var "docker_images_tar_path=./docker-images.tar" \
  packer/aws/
```

## GitHub Actions Build

### Triggers

- **Merge to main or master** – build runs automatically after merge.
- **Push of a tag** matching `release-*` (e.g. `git tag release-1.0.0 && git push origin release-1.0.0`).
- **Manual run** – Actions → Build AMI → Run workflow (from the default branch to test).

### Setup: Secrets and Variables (step by step)

Open the repo on GitHub → **Settings** → **Secrets and variables** → **Actions**. Use the **Secrets** tab for sensitive values and the **Variables** tab for non-sensitive ones.

---

#### Step 1: JFrog (Docker registry)

You need a **service/robot** account for JFrog (not a personal one). If you already have credentials (e.g. from Jenkins or a previous pipeline):

1. **Secrets** → **New repository secret**
   - **Name:** `DOCKER_REGISTRY_USERNAME`  
   - **Value:** username-ul JFrog (service account)
2. **Secrets** → **New repository secret**
   - **Name:** `DOCKER_REGISTRY_PASSWORD`  
   - **Value:** parola sau token-ul acelui cont

Optional (dacă registry-ul nu e medneo-docker.jfrog.io):

3. **Variables** → **New repository variable**
   - **Name:** `DOCKER_REGISTRY`  
   - **Value:** `medneo-docker.jfrog.io` (sau alt host)

Optional (dacă folosești alt tag pentru imaginea vault-otp-ui):

4. **Variables** → **New repository variable**
   - **Name:** `VAULT_OTP_UI_IMAGE`  
   - **Value:** ex. `medneo-docker.jfrog.io/vault-otp-ui:1.0.0`

După Step 1 poți rula workflow-ul doar până la Docker login/pull; build-ul Packer va eșua fără AWS.

---

#### Step 2: AWS (OIDC role și account)

Workflow-ul nu folosește access key / secret key. Folosește **OIDC**: GitHub primește un token temporar și îl schimbă cu AWS pentru credențiale. Trebuie să existe deja un **IAM role** configurat pentru GitHub Actions.

**Unde le poți lua:**

- **Din repo-ul golden-images-base-os**  
  Dacă ai drepturi: Settings → Secrets and variables → Actions. Acolo sunt deja:
  - `AWS_ROLE_ARN`
  - `AWS_SOURCE_AMI_OWNER`
  - `AWS_REGION`  
  Poți crea în packer-vault-otp-ui **același nume de secret** și **aceleași valori** (role ARN și account ID trebuie să rămână la fel).  
  **Important:** IAM role-ul trebuie să aibă în trust policy și repo-ul `medneo/packer-vault-otp-ui`. Dacă trust policy permite doar `golden-images-base-os`, platform/infra trebuie să adauge și acest repo.

- **De la echipa platform / infra**  
  Dacă nu mai ai acces la secret-ele din golden-images-base-os, ceri:
  - **ARN-ul rolului IAM** folosit pentru GitHub Actions (Packer/EC2) → îl pui în `AWS_ROLE_ARN`
  - **Account ID-ul AWS** (12 cifre) → îl pui în `AWS_SOURCE_AMI_OWNER`
  - (Opțional) **Region** → `AWS_REGION`, ex. `eu-central-1`

Pași în GitHub (packer-vault-otp-ui):

1. **Secrets** → **New repository secret**
   - **Name:** `AWS_ROLE_ARN`  
   - **Value:** ex. `arn:aws:iam::123456789012:role/github-actions-packer`
2. **Secrets** → **New repository secret**
   - **Name:** `AWS_SOURCE_AMI_OWNER`  
   - **Value:** account ID (12 cifre) pentru golden AMI, sau `099720109477` dacă folosești Ubuntu Canonical
3. (Opțional) **Secrets** → **New repository secret**
   - **Name:** `AWS_REGION`  
   - **Value:** `eu-central-1`  
   Dacă nu îl pui, workflow-ul folosește `eu-central-1` implicit.

---

#### Step 3: Variables pentru base AMI

**Opțiune A – Doar Ubuntu LTS (Canonical, fără golden image)**  
Baza e ultimul Ubuntu LTS oficial de la Canonical. Recomandat dacă nu folosești golden-images-base-os.

1. **Variables** → **New repository variable**
   - **Name:** `USE_GOLDEN_IMAGE`  
   - **Value:** `false`
2. **Secrets:** `AWS_SOURCE_AMI_OWNER` trebuie să fie **`099720109477`** (Canonical).
3. **Variables** → **New repository variable** (opțional)
   - **Name:** `BASE_AMI_UBUNTU_VERSION`  
   - **Value:** `22.04` sau `24.04` (LTS). Implicit: `22.04`.

**Opțiune B – Golden image (golden-images-base-os)**  
Baza e AMI-ul vostru `golden-ubuntu-*-prod-*`.

1. **Variables** → **New repository variable**
   - **Name:** `BASE_AMI_NAME_PATTERN`  
   - **Value:** `golden-ubuntu-*-prod-*`
2. **Secrets:** `AWS_SOURCE_AMI_OWNER` = account ID-ul vostru (12 cifre).

---

#### Checklist final

| Tip   | Nume                      | Unde îl pui | Exemplu / notă |
|-------|---------------------------|------------|-----------------|
| Secret| `DOCKER_REGISTRY_USERNAME`| Secrets    | user JFrog      |
| Secret| `DOCKER_REGISTRY_PASSWORD`| Secrets    | parola/token    |
| Secret| `AWS_ROLE_ARN`           | Secrets    | de la golden-images sau infra |
| Secret| `AWS_SOURCE_AMI_OWNER`   | Secrets    | `099720109477` (Ubuntu LTS) sau account ID (golden image) |
| Secret| `AWS_REGION`             | Secrets (opțional) | `eu-central-1` |
| Variable | `USE_GOLDEN_IMAGE`     | Variables  | `false` pentru Ubuntu LTS only |
| Variable | `BASE_AMI_UBUNTU_VERSION` | Variables (opțional) | `22.04` sau `24.04` (doar când USE_GOLDEN_IMAGE=false) |
| Variable | `BASE_AMI_NAME_PATTERN` | Variables  | `golden-ubuntu-*-prod-*` (doar când folosești golden image) |
| Variable | `DOCKER_REGISTRY`       | Variables (opțional) | `medneo-docker.jfrog.io` |
| Variable | `VAULT_OTP_UI_IMAGE`    | Variables (opțional) | `medneo-docker.jfrog.io/vault-otp-ui:1.0.0` |

### GitHub OIDC Trust Policy (docs only)

Add this trust policy to the IAM role used by GitHub Actions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:medneo/packer-vault-otp-ui:*"
        }
      }
    }
  ]
}
```

Replace `ACCOUNT_ID` with your AWS account ID and `medneo/packer-vault-otp-ui` with your repo.

### Required IAM Permissions

The role must allow: EC2 (run, terminate, create AMI, describe), EBS (create snapshot, create volume, delete snapshot), IAM (PassRole for instance profile if used).

## Rollout Steps (Manual)

1. Build AMI via GitHub Actions: merge to main/master (auto), push a `release-*` tag, or run the "Build AMI" workflow manually.
2. Note the AMI ID from the workflow summary.
3. Update your launch template or Terraform to use the new AMI ID.
4. Deploy new instances (blue/green or rolling as per your process).
5. Run the Verification Checklist in the Operational Runbook.

## Infrastructure Requirements

### ALB + ACM (Primary, Recommended)

- **ALB Listeners**: 80 redirect to 443; 443 forward to target group HTTP:8080.
- **ACM Certificate**: SAN for `vault-otp-ui.medneo.com` and `vault-otp-ui.beyond-imaging.com`.
- **DNS**: CNAME or A (alias) for both hostnames to the ALB.
- **Target Group**: HTTP health check port 8080, path `/healthz`.
- **Security Groups**: ALB allow 80, 443; instance allow 8080 from ALB SG only.

### Optional Local TLS (Let's Encrypt)

For environments where ALB termination is not used:

1. Copy or symlink `Caddyfile.tls` to `/opt/vault-otp-ui/Caddyfile.tls`.
2. Set `ACME_EMAIL` environment variable.
3. Run: `docker compose -f docker-compose.yml -f docker-compose-tls-override.yml up -d`
4. Ensure DNS for both hostnames points to this instance.
5. Persist the `tls_certs_caddy` volume for certificate renewal.

### Legacy: docker-compose-tls.yml (hitch-based)

Deprecated for AWS. Kept only for vSphere builds. Use ALB + ACM for AWS. Use `docker-compose-tls-override.yml` for optional local TLS.

## Operational Runbook

### Verification Checklist

1. **On the instance** (SSM Session Manager or SSH):
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/healthz
   ```
   Expected: `200`.

2. **ALB target group**: Targets should be healthy. Health check path `/healthz`, port 8080.

3. **Both hostnames**:
   ```bash
   curl -sI https://vault-otp-ui.medneo.com/
   curl -sI https://vault-otp-ui.beyond-imaging.com/
   ```
   Both should return 200 and the expected UI.

### Logs

- **systemd**: `journalctl -u vault-otp-ui.service -f`
- **Docker compose**: `cd /opt/vault-otp-ui && docker compose logs -f`

### Rollback

1. Note the previous AMI ID (from a prior build summary or Terraform state).
2. Update the launch template or Terraform to use the old AMI ID.
3. Terminate instances (or let ASG replace them with the old launch template).
4. Redeploy. Verify both hostnames and `/healthz` as above.

## File Layout

```
.
├── .github/workflows/
│   ├── ci.yml           # Packer fmt/validate on PR
│   └── build.yml        # Packer build on main/tags
├── packer/
│   ├── aws/
│   │   ├── build.pkr.hcl
│   │   └── variables.pkr.hcl
│   └── systemd/
│       └── vault-otp-ui.service
├── scripts/
│   └── install-app.sh
├── docker-compose-vault-otp-ui.yml   # Default HTTP (ALB + ACM)
├── docker-compose-tls-override.yml   # Optional Caddy TLS
├── docker-compose-tls.yml            # Deprecated (hitch, vSphere only)
├── nginx-healthz.conf                # /healthz sidecar config
├── Caddyfile.tls
└── docs/
    └── README.md
```
