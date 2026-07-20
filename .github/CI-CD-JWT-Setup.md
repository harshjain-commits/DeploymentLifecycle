# CI/CD JWT Setup Guide

One-time setup for GitHub Actions to deploy to Salesforce using the **JWT
bearer OAuth flow** (headless, no user interaction).

The pipeline is designed for the following branch promotion model:

```
feature/*  --PR-->  SIT   --PR-->  UAT   --PR-->  main (= PROD)
                     |               |              |
                     v               v              v
                   SIT org         UAT org        PROD org
```

Each environment uses its own secrets (`_SIT`, `_UAT`, `_PROD`) so credentials
can be rotated independently. For the initial demo you only need to configure
the **SIT** environment; UAT and PROD deploys will skip gracefully with a
warning until their secrets are populated.

---

## Prerequisites

- `openssl` installed locally (macOS and most Linux distros ship with it).
- Admin access to a Salesforce org (Developer Edition, Sandbox, or Production).
- Owner or Admin access to the GitHub repository.
- A dedicated **integration user** in each org (recommended, not required for
  the demo — you can reuse your admin user for SIT).

---

## Step 1 — Generate a certificate + private key

Run the helper script for each environment you want to configure. For the
demo, start with SIT:

```bash
./scripts/ci/generate-jwt-cert.sh sit
```

Output lands in `ci/keys/sit/`:

- `server.key` — private key, **never commit this**
- `server.crt` — public cert, uploaded to Salesforce

The `ci/keys/` directory is already listed in `.gitignore`.

---

## Step 2 — Create the External Client App in Salesforce

Salesforce is migrating away from Connected Apps to **External Client Apps**
(ECAs). New integrations should use ECAs. The JWT bearer flow works exactly
the same on the wire — only the Salesforce-side setup UI has changed.

Do this in the org you want CI/CD to deploy to (SIT first).

### 2a. Create the app shell

1. **Setup → Quick Find → "External Client Apps"** → **External Client App
   Manager** → click **New External Client App**.
2. Fill in the **Basic Information** section:
   - **External Client App Name**: `Bedrock DevSecOps CI`
   - **API Name**: `Bedrock_DevSecOps_CI`
   - **Contact Email**: your email
   - **Distribution State**: `Local` (org-only; do not package)

### 2b. Configure OAuth settings

3. Expand **API (Enable OAuth Settings)** and check **Enable OAuth**.
   - **Callback URL**: `http://localhost:1717/OauthRedirect`
     (Not used for JWT, but the form requires a non-empty value.)
   - Check **Enable Client Credentials Flow**? → leave **unchecked** (JWT
     bearer is a different flow).
   - Check **Enable JWT Bearer Flow** → this is the important one.
   - Check **Use digital signatures** → **Choose File** → upload
     `ci/keys/sit/server.crt`.
   - Uncheck **Require Proof Key for Code Exchange (PKCE)** — PKCE applies to
     the web server flow, not JWT.
   - Uncheck **Require Secret for the Web Server Flow** and **Require Secret
     for the Refresh Token Flow** (JWT does not send a secret).
   - Under **OAuth Scopes**, move these to the **Selected** column:
     - `Manage user data via APIs (api)`
     - `Perform requests at any time (refresh_token, offline_access)`
     - `Access the Salesforce API Platform (sfap_api)` — if listed
4. Click **Create** (or **Save**). Salesforce may show a "changes can take up
   to 10 minutes" screen — that's normal for ECAs too.

### 2c. Configure the app's policies (separate from the app definition)

Unlike Connected Apps, an ECA keeps **Policies** in their own tab so they can
be edited and version-controlled independently.

5. Back on the ECA detail page, open the **Policies** tab → click **Edit**.
6. Under **OAuth Policies**:
   - **Permitted Users** → _Admin approved users are pre-authorized_
   - **IP Relaxation** → _Relax IP restrictions_
   - **Refresh Token Policy** → _Refresh token is valid until revoked_
     (any value works for JWT — we don't use refresh tokens)
7. Save.

### 2d. Pre-authorize the integration user

Because you chose "Admin approved users are pre-authorized" in Step 2c, JWT
auth will only succeed for users whose Profile or Permission Set is explicitly
authorized on this app.

8. Still on the **Policies** tab, scroll to the **App Authorization** section
   (in some releases this is a separate **App Users** or **User Access** tab).
9. Click **Add Profiles** (or **Manage Profiles**) → select the profile of the
   user CI will authenticate as. For the quickest demo setup, add
   **System Administrator**. For production, prefer a dedicated integration
   user with a dedicated **Permission Set** added via **Add Permission Sets**.
10. Save.

### 2e. Copy the Consumer Key

11. Open the **Settings** tab of the ECA (may also be labelled
    **OAuth Settings** / **App Settings**).
12. Under **OAuth Settings → Consumer Key and Secret**, click
    **Consumer Key and Secret** (or **Manage Consumer Details**) → verify
    your identity when prompted.
13. Copy the **Consumer Key** — this is the `SFDX_CONSUMER_KEY_SIT` secret in
    Step 4. (You do not need the Consumer Secret for JWT.)

> **Fallback**: if your org still has Connected Apps enabled and the ECA UI
> is not visible, the same JWT flow works with a classic Connected App via
> **Setup → App Manager → New Connected App**, with the exact same OAuth
> scope selections and the same "Admin approved users are pre-authorized"
> policy. Follow the corresponding Step-2 flow in the Salesforce docs; the
> GitHub-side wiring in Step 4 is identical.

---

## Step 3 — Identify the integration user

Grab three values you'll need for GitHub secrets:

- **Username**: `Setup → Users → Users`, copy the username of your CI
  integration user (looks like `you@company.com.sandboxname` for a sandbox).
- **My Domain URL**: `Setup → Company Settings → My Domain`, copy the
  **Current My Domain URL** (e.g. `https://acme--sit.sandbox.my.salesforce.com`).
- **Consumer Key**: from Step 2e.

Test the JWT flow locally before touching GitHub:

```bash
sf org login jwt \
  --client-id <CONSUMER_KEY> \
  --jwt-key-file ci/keys/sit/server.key \
  --username <USERNAME> \
  --instance-url <MY_DOMAIN_URL> \
  --alias sit-test
```

If you see `Successfully authorized ... with org ID ...`, you're good.
If you get `user hasn't approved this consumer`, revisit Step 2d and add the
integration user's profile/perm set to the External Client App's
**Policies → App Authorization** section.

---

## Step 4 — Add GitHub Environment + Secrets

1. In GitHub: **Settings → Environments → New environment** → name it `sit`.
2. **Do not add "Required reviewers" or restrict "Deployment branches" on the `sit` environment.** The PR-validation workflow (`.github/workflows/ci-pull-request.yml`) references `environment: sit` so it can read these secrets from every feature-branch PR — any protection rule on the environment will block those PR runs waiting for approval. Reviewers are only appropriate on `production` (see below).
3. Click into the environment, then **Add secret** four times:

| Secret name             | Value                                                         |
| ----------------------- | ------------------------------------------------------------- |
| `SFDX_JWT_KEY_SIT`      | Full contents of `ci/keys/sit/server.key`, including the      |
|                         | `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` |
|                         | lines and trailing newline                                    |
| `SFDX_CONSUMER_KEY_SIT` | Consumer Key from Step 2e                                     |
| `SFDX_USERNAME_SIT`     | Integration user's username                                   |
| `SFDX_INSTANCE_URL_SIT` | My Domain URL from Step 3 (no trailing slash)                 |

Repeat the same 4-secret pattern for `uat` and `production` environments when
you provision those orgs (with `_UAT` and `_PROD` suffixes).

For the **`production`** environment, also enable **Required reviewers** so
PROD deployments halt for human approval by the Release Train Engineer.

---

## Step 5 — Trigger the pipeline

Two ways to fire the first deploy:

**a) Via a PR** — the recommended path:

```bash
git checkout -b feature/first-ci-run
# make any trivial change under force-app/, e.g. edit a description
git commit -am "chore(ci): first pipeline run"
git push -u origin feature/first-ci-run
# then open a PR from feature/first-ci-run into SIT on GitHub
```

The `PR Validation` workflow will run — expect Format & Lint, Code Analyzer,
and Validate Deploy (check-only) jobs.

Merge the PR into `SIT`. The `Deploy` workflow will kick off and push the
metadata into your SIT sandbox.

**b) Manually** — use the workflow_dispatch entry point:

- GitHub → **Actions** → **Deploy** → **Run workflow** → pick `sit`.

---

## Step 6 — Troubleshooting

| Symptom                                                          | Fix                                                                                                                                       |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `user hasn't approved this consumer`                             | The integration user's profile or perm set isn't pre-authorized on the ECA (Step 2d).                                                     |
| `invalid_client_id`                                              | Consumer Key was copied incorrectly, or you copied from the wrong org.                                                                    |
| `invalid_grant: audience`                                        | `SFDX_INSTANCE_URL_*` is wrong. Use the My Domain URL, not `https://test.salesforce.com` for sandboxes on custom domains.                 |
| `IP restrictions apply`                                          | Step 2.6 — set IP Relaxation to "Relax IP restrictions".                                                                                  |
| `INVALID_LOGIN: Invalid username, password, security token`      | You accidentally used web/password auth. Confirm you invoked `sf org login jwt` with `--jwt-key-file`, not `sf org login web`.            |
| Workflow logs show `JWT secrets not configured; skipping deploy` | One or more of the 4 secrets is missing or has an empty value. Recheck Step 4.                                                            |
| Deploy fails with `Missing metadata`                             | Make sure `.forceignore` isn't excluding files you expect to deploy. The pipeline deploys everything under `force-app/`.                  |
| Local `sf org login jwt` works but CI fails                      | Confirm the secret contains the ENTIRE key including header/footer lines, and that CR/LF weren't mangled by your paste (use plain paste). |

---

## Rotation

To rotate the credential:

1. Run `./scripts/ci/generate-jwt-cert.sh sit` (delete the old `ci/keys/sit/`
   first).
2. Upload the new `server.crt` to the External Client App
   (**Settings → OAuth Settings → Edit → Use digital signatures →
   Choose File**), then save.
3. Update the two changed GitHub secrets (`SFDX_JWT_KEY_SIT`, plus
   `SFDX_CONSUMER_KEY_SIT` if you rebuilt the ECA from scratch).

Rotate at least annually or immediately if a key is suspected leaked.

---

## Security posture

- Private keys never leave the integration user's machine or GitHub Secrets
  storage (encrypted at rest and only decrypted at runtime by the runner).
- The workflow writes the key to a local file with `chmod 600`, uses it once,
  then deletes it (`rm -f ./server.key`).
- All Salesforce values in workflows are consumed via `env:` bindings from
  secrets — never interpolated directly into `run:` blocks — to prevent the
  workflow-injection class of vulnerabilities.
- `production` environment protection rules add a human approval gate before
  any PROD deploy.
