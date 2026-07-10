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

## Step 2 — Create the Connected App in Salesforce

Do this in the org you want CI/CD to deploy to (SIT sandbox first).

1. **Setup → App Manager → New Connected App**.
2. Fill in:
   - **Connected App Name**: `Bedrock DevSecOps CI`
   - **API Name**: `Bedrock_DevSecOps_CI`
   - **Contact Email**: your email
3. Under **API (Enable OAuth Settings)** check **Enable OAuth Settings**.
   - **Callback URL**: `http://localhost:1717/OauthRedirect`
     (Not used for JWT, but required by the form.)
   - **Use digital signatures**: check the box, then **Choose File** and
     upload `ci/keys/sit/server.crt`.
   - **Selected OAuth Scopes** (add these to the "Selected" column):
     - `Manage user data via APIs (api)`
     - `Perform requests at any time (refresh_token, offline_access)`
     - `Access the Salesforce API Platform (sfap_api)` (if available)
4. Uncheck **Require Secret for Web Server Flow** and **Require Secret for
   Refresh Token Flow** (JWT doesn't use the secret).
5. **Save** → confirm the wait screen → **Continue**.

Once saved:

6. On the Connected App detail page, click **Manage** → **Edit Policies**.
   - Set **Permitted Users** to **Admin approved users are pre-authorized**.
   - Set **IP Relaxation** to **Relax IP restrictions**.
   - Save.
7. Still on the detail page (top of app), click **Manage Consumer Details**
   (you'll be asked to verify). Copy the **Consumer Key** — you'll need it in
   Step 4.
8. Under **Manage → Profiles / Permission Sets**, add the profile or perm set
   of the integration user that CI will authenticate as. (For quickest demo
   setup, add the **System Administrator** profile.)

---

## Step 3 — Identify the integration user

Grab three values you'll need for GitHub secrets:

- **Username**: `Setup → Users → Users`, copy the username of your CI
  integration user (looks like `you@company.com.sandboxname` for a sandbox).
- **My Domain URL**: `Setup → Company Settings → My Domain`, copy the
  **Current My Domain URL** (e.g. `https://acme--sit.sandbox.my.salesforce.com`).
- **Consumer Key**: from Step 2.7.

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
If you get `user hasn't approved this consumer`, revisit Step 2.6 and add the
integration user's profile/perm set to the Connected App.

---

## Step 4 — Add GitHub Environment + Secrets

1. In GitHub: **Settings → Environments → New environment** → name it `sit`.
2. (Optional) Add reviewers if you want approval gates on SIT.
3. Click into the environment, then **Add secret** four times:

| Secret name              | Value                                                          |
| ------------------------ | -------------------------------------------------------------- |
| `SFDX_JWT_KEY_SIT`       | Full contents of `ci/keys/sit/server.key`, including the       |
|                          | `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`  |
|                          | lines and trailing newline                                     |
| `SFDX_CONSUMER_KEY_SIT`  | Consumer Key from Step 2.7                                     |
| `SFDX_USERNAME_SIT`      | Integration user's username                                    |
| `SFDX_INSTANCE_URL_SIT`  | My Domain URL from Step 3 (no trailing slash)                  |

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
| `user hasn't approved this consumer`                             | The integration user's profile or perm set isn't added to the Connected App (Step 2.6 / 2.8).                                             |
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
2. Upload the new `server.crt` to the Connected App
   (**Manage → Edit → Digital Signatures**).
3. Update the two changed GitHub secrets (`SFDX_JWT_KEY_SIT`,
   `SFDX_CONSUMER_KEY_SIT` if you created a new Connected App).

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
