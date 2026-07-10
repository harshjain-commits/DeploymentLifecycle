# Bedrock Enterprises — DevSecOps Demo (Salesforce DX)

> Reference implementation and presentation deliverable for the
> **Bedrock Scenario — Development Lifecycle and Deployment (2025)**
> domain badge.

This repository contains:

1. A **speaker-ready presentation** for the CTO / Program / Release Management
   audience: [`docs/Bedrock-DevSecOps-Presentation.md`](docs/Bedrock-DevSecOps-Presentation.md).
2. A **working demo Salesforce app** — Bedrock Financial Customer Onboarding —
   built to the requirements in the scenario brief (custom object + Apex + Flow
   - permission set, managed in source control with an automated pipeline).
3. A **GitHub Actions CI/CD pipeline** implementing the branching, environment,
   security, and release patterns described in the presentation.

The artefacts are intentionally aligned: every slide that describes a
DevSecOps pattern has a matching artefact in the repo that demonstrates it.

---

## Repo map

```
.
├── docs/
│   ├── Bedrock-DevSecOps-Presentation.md     # Main deliverable — speaker deck
│   ├── Bedrock-Branching-Strategy.md         # Companion to Slide 8
│   ├── Bedrock-Environment-Strategy.md       # Companion to Slide 9
│   ├── Bedrock Enterprises - Background.pdf  # Source brief (provided)
│   └── Bedrock Scenario - Development Lifecycle and Deployment - 2025.pdf
├── force-app/main/default/
│   ├── applications/Bedrock_Onboarding.app   # Lightning app for the demo
│   ├── classes/                              # Apex service, handler, tests
│   ├── triggers/                             # Onboarding_Request trigger
│   ├── flows/                                # Auto-triage record-triggered flow
│   ├── objects/Onboarding_Request__c/        # Custom object + fields
│   ├── permissionsets/                       # Bedrock_Onboarding_Admin
│   └── tabs/                                 # Onboarding Request tab
├── scripts/
│   ├── apex/seed-onboarding-requests.apex    # Seed sample data
│   └── soql/onboarding-requests.soql         # Operational queue query
└── .github/
    ├── CODEOWNERS                            # Multi-SI access control
    ├── pull_request_template.md              # Enforces Jira link + checklists
    └── workflows/
        ├── ci-pull-request.yml               # Lint, scan, validate (every PR)
        ├── cd-deploy.yml                     # Auto deploy to DEV/UAT/STG/PROD
        ├── hotfix-fast-path.yml              # Hotfix process (Appendix D)
        └── security-scan.yml                 # CodeQL, gitleaks, dep review
```

---

## The Bedrock Financial Onboarding demo

A minimal but realistic slice of one of the projects in the scenario — a
customer onboarding workflow for Bedrock Financial's wealth-management
business.

| Component                                      | Type           | Demonstrates                         |
| ---------------------------------------------- | -------------- | ------------------------------------ |
| `Onboarding_Request__c`                        | Custom object  | Source-control of metadata           |
| `OnboardingRequestService.cls`                 | Apex (service) | Reusable business logic + invocable  |
| `OnboardingRequestTriggerHandler.cls`          | Apex (handler) | Thin trigger pattern                 |
| `OnboardingRequestTrigger.trigger`             | Apex trigger   | Before-insert rule application       |
| `OnboardingRequestServiceTest.cls`             | Apex test      | >90% coverage, runs in CI            |
| `Onboarding_Request_Auto_Triage.flow-meta.xml` | Flow           | Record-triggered post-insert routing |
| `Bedrock_Onboarding_Admin.permissionset`       | Permission set | RBAC for the new feature             |
| `Bedrock_Onboarding.app`                       | Lightning app  | Stakeholder-facing UI for the demo   |

The business rule (encapsulated in `OnboardingRequestService`):

- Risk score is derived from net-worth tier (KYC stub).
- Priority is derived from risk score (`>=75 Critical`, `>=50 High`, else `Medium`).
- Defaults applied for blank Status and Submitted Date.
- After insert, a record-triggered Flow auto-moves High/Critical requests to
  `In Review` so the operations team can pick them up.

### Try it locally

```bash
# 1. Authenticate a Dev Hub
sf org login web --set-default-dev-hub --alias devhub

# 2. Spin up a scratch org
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias bedrock-demo --set-default --duration-days 7

# 3. Deploy
sf project deploy start --source-dir force-app

# 4. Assign permissions
sf org assign permset --name Bedrock_Onboarding_Admin

# 5. Seed sample data
sf apex run --file scripts/apex/seed-onboarding-requests.apex

# 6. Run tests
sf apex run test --code-coverage --result-format human --wait 10

# 7. Open the app
sf org open --path /lightning/app/Bedrock_Onboarding
```

---

## The CI/CD pipeline

| Workflow               | Trigger                  | Purpose                                                                     |
| ---------------------- | ------------------------ | --------------------------------------------------------------------------- |
| `ci-pull-request.yml`  | PR opened/updated        | Prettier, ESLint, Salesforce Code Analyzer, scratch-org deploy + Apex tests |
| `cd-deploy.yml`        | Push to `main` / release | Auto-deploy to DEV (push) and UAT → STG → PROD (release)                    |
| `hotfix-fast-path.yml` | Manual dispatch          | Hotfix branch fast-path to PROD + auto retro-merge PR                       |
| `security-scan.yml`    | Nightly / push to `main` | CodeQL, gitleaks secret scan, dependency review                             |

### Required GitHub secrets

| Secret                 | Used in                     | Source                                         |
| ---------------------- | --------------------------- | ---------------------------------------------- |
| `SFDX_AUTH_URL_DEVHUB` | `ci-pull-request.yml`       | `sf org display --target-org devhub --verbose` |
| `SFDX_AUTH_URL_DEV`    | `cd-deploy.yml`             | Same, for the DEV sandbox                      |
| `SFDX_AUTH_URL_UAT`    | `cd-deploy.yml`             | Same, for the UAT sandbox                      |
| `SFDX_AUTH_URL_STG`    | `cd-deploy.yml`             | Same, for the STG full sandbox                 |
| `SFDX_AUTH_URL_PROD`   | `cd-deploy.yml`, `hotfix-*` | Per-org service principal (Vault) for PROD-A   |
| `SFDX_AUTH_URL_PROD_B` | `hotfix-fast-path.yml`      | Per-org service principal (Vault) for PROD-B   |

> **Note**: the pipeline is designed to **gracefully no-op** when an
> environment's secret isn't configured yet — this is how Phase 1 of the
> roadmap can land the pipeline before all sandboxes exist.

---

## Mapping presentation → repo artefacts

| Presentation slide | Repo artefact                                                                           |
| ------------------ | --------------------------------------------------------------------------------------- |
| 8 — Branching      | `docs/Bedrock-Branching-Strategy.md`, `.github/CODEOWNERS`, `pull_request_template.md`  |
| 9 — Environments   | `docs/Bedrock-Environment-Strategy.md`, `config/project-scratch-def.json`               |
| 10 — CI/CD         | `.github/workflows/*.yml`                                                               |
| 12 — QA            | `force-app/main/default/classes/OnboardingRequestServiceTest.cls`                       |
| 13 — Governance    | `.github/CODEOWNERS`, `pull_request_template.md`, evidence-pack step in `cd-deploy.yml` |
| 15 — Demo          | All of `force-app/`, plus `scripts/apex/seed-onboarding-requests.apex`                  |

---

## Local developer setup

```bash
npm ci          # install dev-tooling (Prettier, ESLint, jest, Apex formatter)
npm run prettier:verify
npm run lint
npm test
```

Husky pre-commit hook runs Prettier and ESLint on staged files.

---

## Further reading

- [`docs/Bedrock-DevSecOps-Presentation.md`](docs/Bedrock-DevSecOps-Presentation.md) — the main deliverable.
- [`docs/Bedrock-Branching-Strategy.md`](docs/Bedrock-Branching-Strategy.md)
- [`docs/Bedrock-Environment-Strategy.md`](docs/Bedrock-Environment-Strategy.md)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce Code Analyzer v5](https://developer.salesforce.com/docs/platform/salesforce-code-analyzer/overview)
