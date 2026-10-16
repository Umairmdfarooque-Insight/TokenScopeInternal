// ── TokenScope — Internal (Insight) environment parameters ──────────────
//
// Deploys into the existing resource group `token_scope`
// (subscription 4b9be414-9438-4356-b1d7-a649d4a0d809). The resource
// group itself lives in East US, but its *resources* are placed in West
// US 3 instead — see the `location` param below for why.
//
// Posture: public networking, Front Door off — same shape as the
// documented "sandbox" example, chosen deliberately for first bring-up
// since no production-grade Entra/Anthropic/GitHub secrets exist yet.
// This is a cheap, reversible starting point: raise `env` to 'staging' or
// 'production', and/or flip the two posture switches, in a later change
// once the app is confirmed working and real secrets are in hand. See
// docs/DEPLOY-AZURE.md.
//
// @secure() params (passwords, keys, OIDC secrets) are NEVER written here —
// they are passed at apply time only, by the infra.yml GitHub Actions
// workflow, reading them out of GitHub Actions secrets.

using '../main.bicep'

param env = 'sandbox'
// NOT 'eastus': this subscription is Azure-policy-restricted from
// provisioning PostgreSQL Flexible Server in eastus, eastus2, westus2,
// southcentralus and westeurope ("Provisioning is restricted in this
// region" / "ParameterOutOfRange: Version should be in: []" is what that
// looks like when Bicep hits it). westus3 is confirmed open for this
// subscription (verified with `az postgres flexible-server list-skus
// --location westus3`) and is also a first-class region in
// `main.bicep`'s naming map, so resource names come out clean
// (ca-tokenscope-sandbox-wus3, not a raw region string). A resource
// group's own region does not have to match where its resources live,
// so this does not require moving `token_scope` itself.
param location = 'westus3'
param projectName = 'tokenscope'
param imageTag = 'latest'          // deploy.yml overrides this per roll

// ── Required @secure() (placeholders only; real values passed at apply time) ──
param pgAdminLogin = ''
param pgAdminPassword = ''
param sessionSecret = ''
param hmacSessionKey = ''
param internalWorkerHmacKey = ''

// ── Auth (Entra ID OIDC) — left empty for first bring-up ─────────────────
// The app boots without OIDC and serves the dev-mode UI until these are set.
// redirectUri = https://<fqdn>/auth/entra/callback — the fqdn is only known
// after the container app provisions, so this is filled in on a second apply.
param entraIdTenantId = ''
param entraIdClientId = ''
param entraIdClientSecret = ''
param entraIdRedirectUri = ''

// First Entra sign-in matching this email is JIT-created as `admin`.
// Set this to the first real admin's email before enabling OIDC.
param bootstrapAdminEmail = ''

// Demo persona override — convenient while there is no real OIDC yet.
// Flip to false once Entra sign-in is configured.
param allowPersonaOverride = true

// ── External APIs — left empty (pollers no-op until configured) ─────────
param anthropicApiKey = ''

// ── Networking / Front Door ──────────────────────────────────────────────
param enablePrivateNetworking = false
param enableFrontDoor = false

param keyVaultCreateMode = 'default'
