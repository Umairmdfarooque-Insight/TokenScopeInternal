# Deploying TokenScope to Insight's Azure (internal environment)

This document explains, in plain language, how TokenScope gets hosted in
your Azure resource group and kept up to date automatically, what has
already been done for you, and what you still need to do yourself (a
handful of steps that only you can do, explained below).

Written: 2026-10-16, by Claude Code, for umair.mdfarooque@insight.com.

---

## 1. The short version

- **Where it's hosted:** Azure resource group `token_scope`, subscription
  `4b9be414-9438-4356-b1d7-a649d4a0d809` ("Visual Studio Enterprise
  Subscription"), region **East US**.
- **Where the code lives:** `https://github.com/Umairmdfarooque-Insight/TokenScopeInternal`,
  pushed from this machine's local copy of the TokenScope source
  (`tokenscope-public`), full history.
- **How it deploys:** Two GitHub Actions workflows, triggered automatically
  (or by hand), build the app into a container image and apply the Azure
  infrastructure. No one needs to run commands from a laptop day-to-day.
- **What's left:** A few steps need *you* specifically — either because
  they need a credential/login only you have, or because Claude Code's own
  safety rules don't let an AI assistant perform them automatically (granting
  Azure permissions, and generating real secret values). See **Section 3**.

---

## 2. What's already been done, and why

| # | What | Why |
|---|---|---|
| 1 | Found that subscription `4b9be414-...` contains resource group `token_scope` (East US, empty). | You gave me this subscription ID directly after I found two *other*, differently-numbered subscriptions with the same display name in your account — those did not have the RG. |
| 2 | Checked your access on `token_scope` → found you only hold **"Role Based Access Control Administrator"**, which can *grant* roles but cannot itself create anything. | Confirmed with a real dry-run deployment, which Azure rejected with `AuthorizationFailed`. This is the main thing blocking automatic deployment right now (Section 3.1). |
| 3 | Created an Azure AD **App Registration** named `TokenScopeInternal-GitHubActions-CD` (client ID `c92c3a6c-f05b-4825-980b-27b5d1c3d165`), plus its service principal. | This is the identity GitHub Actions uses to deploy to Azure — not your own login. |
| 4 | Added two **federated credentials** (OIDC trust) to that app: one trusting pushes to this repo's `main` branch, one trusting pull requests. | This lets GitHub Actions prove its identity to Azure *without* a stored password/secret — a short-lived token is exchanged at run time instead. More secure than the alternative (a long-lived client secret sitting in GitHub). |
| 5 | Pushed the full TokenScope source code (with history) from this machine to `TokenScopeInternal`, branch `main`. | You chose "push full history" over a single squashed commit, so the new repo mirrors the original exactly. |
| 6 | Added `infra/parameters/internal.bicepparam` — the settings file describing *this* deployment (region East US, the `token_scope` resource group's posture). | Needed so the infrastructure script (`infra/main.bicep`) knows what to build for this specific environment. I set the posture to match the project's own "sandbox" example (public networking, no Front Door) — see Section 2.1 for why. |
| 7 | Added `.github/workflows/infra.yml` — builds/updates all Azure resources (database, container app, key vault, etc.) from the Bicep files, run by hand from GitHub's Actions tab. | Kept **manual** on purpose: infrastructure changes (capacity, networking, enabling Front Door) are riskier than a routine app update, so they shouldn't fire automatically on every commit. |
| 8 | Added `.github/workflows/deploy.yml` — builds the app's Docker image and rolls it out, automatically on every push to `main`, with an automatic health check and rollback if it fails. | This is the actual "CI/CD" you asked for: every change you push gets built and deployed automatically, and a bad deploy reverts itself. |

### 2.1 Why I chose a "sandbox-sized" setup, not full production

`infra/parameters/internal.bicepparam` currently sets `env = 'sandbox'`,
keeps the network public (no private VNet), and leaves Front Door (a
web firewall / CDN layer) switched off. I also left real company sign-in
(Microsoft Entra ID) and the Anthropic/GitHub billing-data connections
**unconfigured** for now.

I chose this deliberately, not by default: the project's own documentation
describes exactly this as the recommended **first bring-up** shape — "fast
to stand up, the app boots fine without real sign-in and shows a
developer-persona demo UI instead." Setting up real sign-in or billing
connections requires secrets I don't have (and can't generate myself —
see Section 3.2), so starting there would leave the deployment half-finished.

**Everything about this is changeable later**, without starting over: it's
a few more values in `internal.bicepparam` plus secrets, then re-running
the `Infra deploy (internal)` workflow. Section 5 covers each upgrade.

---

## 3. What only you can do (and exactly how)

### 3.1 Grant the deploy identity permission to create resources

Right now, nothing — not even me — can create resources in `token_scope`
except an identity that's been granted a role like **Contributor**. Your
account's "Role Based Access Control Administrator" role exists
specifically to hand out roles like that, so this is a few commands, not
a support ticket.

Run these from a terminal with Azure CLI installed and signed in as
`umair.mdfarooque@insight.com` (`az login` first if needed):

```bash
SUB="4b9be414-9438-4356-b1d7-a649d4a0d809"
RG="token_scope"
SCOPE="/subscriptions/$SUB/resourceGroups/$RG"
DEPLOY_APP_ID="c92c3a6c-f05b-4825-980b-27b5d1c3d165"   # TokenScopeInternal-GitHubActions-CD

# So you can see/manage the resources in the Azure Portal yourself:
az role assignment create \
  --assignee "umair.mdfarooque@insight.com" \
  --role "Contributor" \
  --scope "$SCOPE"

# So GitHub Actions can create resources in this resource group:
az role assignment create \
  --assignee "$DEPLOY_APP_ID" \
  --role "Contributor" \
  --scope "$SCOPE"

# So GitHub Actions can also grant the app's own managed identity access
# to the Key Vault / ACR / monitoring it creates (Bicep does this itself,
# but needs the right to do it):
az role assignment create \
  --assignee "$DEPLOY_APP_ID" \
  --role "User Access Administrator" \
  --scope "$SCOPE"
```

Both roles are scoped **only to `token_scope`** — not your whole
subscription — so this is as narrow a grant as the deployment needs.

> Why didn't I just run this for you? Claude Code's own safety rules
> block an AI assistant from granting Azure permissions on your behalf —
> that's a deliberate guardrail, not a missing capability. If you'd
> rather I ran it, you can allow that action type for the Bash tool in
> Claude Code's settings and ask me again; otherwise, the three commands
> above are copy-paste-ready.

### 3.2 Generate the app's secrets, and add them to GitHub

The app needs several random secret values (a database password, session
signing keys, etc.). I'm deliberately not generating or seeing these
myself — Claude Code also blocks an assistant from creating real secret
material, so there's nothing to approve here, just values to generate
yourself and paste straight into GitHub (never back into a chat with me).

**Step A — generate the values.** Run each line below yourself (PowerShell,
one at a time) and keep the output — you'll paste each straight into
GitHub in Step B:

```powershell
# Run each of these separately and copy its output:
[Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Maximum 256 }))   # → SESSION_SECRET
[Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Maximum 256 }))   # → HMAC_SESSION_KEY
[Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Maximum 256 }))   # → INTERNAL_WORKER_HMAC_KEY
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))   # → PG_ADMIN_PASSWORD
```

(If you have `openssl` available — e.g. in Git Bash — `openssl rand
-base64 48` does the same thing and is the project's own documented way
to do it.)

For `PG_ADMIN_LOGIN`, pick any plain admin username, e.g. `tokenscope_admin`
(not a secret, just needs to not be `admin`/`root`, which Postgres rejects).

**Step B — add them as GitHub Actions secrets.** Go to
`https://github.com/Umairmdfarooque-Insight/TokenScopeInternal/settings/secrets/actions`
→ **New repository secret**, and add each of these one at a time:

| Secret name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `c92c3a6c-f05b-4825-980b-27b5d1c3d165` |
| `AZURE_TENANT_ID` | `6c637512-c417-4e78-9d62-b61258e4b619` |
| `AZURE_SUBSCRIPTION_ID` | `4b9be414-9438-4356-b1d7-a649d4a0d809` |
| `PG_ADMIN_LOGIN` | the username you picked above |
| `PG_ADMIN_PASSWORD` | the value you generated above |
| `SESSION_SECRET` | the value you generated above |
| `HMAC_SESSION_KEY` | the value you generated above |
| `INTERNAL_WORKER_HMAC_KEY` | the value you generated above |

These three are safe to leave empty for now (just click "New repository
secret" and save with no value, or skip adding them — the workflow treats
a missing secret as an empty string): `ENTRA_TENANT_ID`, `ENTRA_CLIENT_ID`,
`ENTRA_CLIENT_SECRET`, `ANTHROPIC_API_KEY`, `BOOTSTRAP_ADMIN_EMAIL`. Fill
those in later, per Section 5.

The first three values above (client/tenant/subscription ID) are not
secret — they're identifiers, not passwords — so it's fine that they're
written in this document.

### 3.3 (Recommended) Make the repo private

`TokenScopeInternal` is currently a **public** GitHub repo — I didn't
change this, since it needs your own GitHub web session, not something
git/CLI access can do. For an internal company deployment, I'd recommend
making it private: go to the repo → **Settings** → scroll to **Danger
Zone** → **Change visibility** → **Make private**.

---

## 4. First-time setup: putting it all together

Once Section 3's steps are done, bring the app online in this order:

1. **Go to** `https://github.com/Umairmdfarooque-Insight/TokenScopeInternal/actions`.
2. **Run "Infra deploy (internal)"** (click it → "Run workflow" → leave
   the defaults → Run). This creates every Azure resource: the database,
   the container app, the key vault, monitoring, etc. It takes roughly
   15–20 minutes.
   - It's normal for the container app to look unhealthy right after this
     finishes — the container registry it just created is still empty,
     so there's no app image to run yet. That's fixed by the next step.
   - When it finishes, open the job's summary — it prints the live URL,
     the container app name, the registry name, and more (useful later).
3. **Run "Deploy image (internal)"** the same way (or just push any commit
   to `main` — it runs automatically). This builds the actual TokenScope
   app into a container image, pushes it, and rolls the container app to
   it. After this, the app is live and healthy.
4. **Open the URL** from step 2's summary. You'll land on a working
   TokenScope instance with the demo/developer-persona sign-in (since
   real company sign-in isn't configured yet — see Section 5.1).

From here on, **every push to `main` automatically redeploys** — that's
the CI/CD you asked for. No further manual steps for routine code changes.

---

## 5. Turning on the rest, later

### 5.1 Real company sign-in (Microsoft Entra ID)

Right now anyone who opens the app sees a demo "pick a persona" login
screen instead of a real Microsoft sign-in. To switch to real sign-in:

1. In Azure AD, register a new app for TokenScope itself (separate from
   the GitHub Actions one) with a redirect URI of
   `https://<the-url-from-step-2-above>/auth/entra/callback`.
2. Add its tenant ID, client ID, and client secret as the
   `ENTRA_TENANT_ID` / `ENTRA_CLIENT_ID` / `ENTRA_CLIENT_SECRET` GitHub
   secrets (Section 3.2's table).
3. Set `BOOTSTRAP_ADMIN_EMAIL` to the email of whoever should become the
   first admin.
4. In `infra/parameters/internal.bicepparam`, set `param
   allowPersonaOverride = false` (turns off the demo login for good) and
   commit that change.
5. Re-run the **"Infra deploy (internal)"** workflow.

### 5.2 Real usage/billing data (Anthropic, GitHub Copilot)

Add `ANTHROPIC_API_KEY` (an Anthropic organization Admin API key) as a
GitHub secret, then re-run **"Infra deploy (internal)"**. Copilot billing
reconciliation needs a GitHub PAT or GitHub App key, which isn't wired
into the workflow yet — see `docs/PROVIDERS.md` and `docs/CONFIGURATION.md`
in the repo for the exact variables, and extend `infra.yml` the same way
the Anthropic key is wired in, when you're ready for that.

### 5.3 Enabling Front Door (a web firewall in front of the app)

This is a deliberate 3-step dance (so the app and the firewall can learn
about each other) — fully explained in `docs/DEPLOY-AZURE.md`, "Front
Door: the three-phase apply". The short version: run "Infra deploy
(internal)" with the `enableFrontDoor` checkbox on, copy the Front Door
ID it prints, run it once more with that ID filled in.

### 5.4 Promoting from "sandbox" sizing to "staging" or "production"

Change `param env = 'sandbox'` to `'staging'` or `'production'` in
`infra/parameters/internal.bicepparam`, commit, and re-run "Infra deploy
(internal)". This mainly changes resource sizes/retention, not behavior.

---

## 6. Doing it by hand, without GitHub Actions (if CI/CD is ever down)

Everything the workflows do can be run from your own laptop instead.
You'll need Azure CLI installed and logged in (`az login`, then
`az account set --subscription 4b9be414-9438-4356-b1d7-a649d4a0d809`).

**Infra changes** (same as `infra.yml`):
```bash
az deployment group create \
  --resource-group token_scope \
  --template-file infra/main.bicep \
  --parameters infra/parameters/internal.bicepparam \
  --parameters \
    pgAdminLogin=<...> pgAdminPassword=<...> \
    sessionSecret=<...> hmacSessionKey=<...> internalWorkerHmacKey=<...> \
    entraIdTenantId=<...> entraIdClientId=<...> entraIdClientSecret=<...> \
    anthropicApiKey=<...> bootstrapAdminEmail=<...>
```

**Image build + roll** (same as `deploy.yml`): the repo already ships
`scripts/deploy-image.sh` for exactly this — **but note it assumes
resource names like `rg-tokenscope-sandbox-aue`, which don't match this
environment.** For `token_scope`, run the equivalent by hand instead:

```bash
TAG="$(git rev-parse --short HEAD)"
az acr build --registry crtokenscopesandboxeastus \
  --image tokenscope:$TAG --image tokenscope:latest \
  --file Dockerfile .
az containerapp update --name ca-tokenscope-sandbox-eastus \
  --resource-group token_scope \
  --image crtokenscopesandboxeastus.azurecr.io/tokenscope:$TAG
```

(If you ever rename the environment, region, or project in
`internal.bicepparam`, the resource names above change too — see
`infra/main.bicep`'s "Naming Convention" comment block, or just read the
names back from the "Infra deploy" workflow's last run summary.)

---

## 7. Quick reference

| Thing | Value |
|---|---|
| Subscription | `4b9be414-9438-4356-b1d7-a649d4a0d809` |
| Tenant | `6c637512-c417-4e78-9d62-b61258e4b619` (insight.com) |
| Resource group | `token_scope` (East US) |
| GitHub repo | `Umairmdfarooque-Insight/TokenScopeInternal` |
| CI/CD Azure AD app | `TokenScopeInternal-GitHubActions-CD`, client ID `c92c3a6c-f05b-4825-980b-27b5d1c3d165` |
| Container app (after first deploy) | `ca-tokenscope-sandbox-eastus` |
| Container registry | `crtokenscopesandboxeastus.azurecr.io` |
| Key Vault | `kv-tokenscope-sandbox-eastus` |
| Infra settings file | `infra/parameters/internal.bicepparam` |
| CI/CD workflows | `.github/workflows/infra.yml`, `.github/workflows/deploy.yml` |
| Full variable reference | `docs/CONFIGURATION.md` |
| Full infra reference | `docs/DEPLOY-AZURE.md` |

---

## 8. If something goes wrong

- **A deploy fails and the app goes down:** `deploy.yml` (the image
  rollout) automatically rolls back to the last healthy version on
  failure — no action needed. `infra.yml` does not auto-rollback; re-run
  it after fixing whatever it reported, or use `az deployment group
  create` with the previous parameter values.
- **"Infra deploy" fails with `AuthorizationFailed`:** Section 3.1's role
  assignments haven't been done yet, or were done at the wrong scope.
- **"Deploy image" fails because the container app doesn't exist:** run
  "Infra deploy (internal)" first — it creates the registry and app that
  "Deploy image" needs.
- **GitHub Actions can't sign in to Azure ("AADSTS70021" or similar):**
  the federated credential's trusted branch/condition doesn't match how
  the workflow ran. Both workflows here run from `main` (push or manual
  dispatch from `main`), matching the `github-main-branch` federated
  credential already configured — if you add new branches/environments
  that need to deploy, add a matching federated credential first.
