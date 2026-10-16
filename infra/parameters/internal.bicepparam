// ── TokenScope — Internal (Insight) environment parameters ──────────────
//
// Deploys into the existing resource group `token_scope`
// (subscription 4b9be414-9438-4356-b1d7-a649d4a0d809, region East US).
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
param location = 'eastus'          // matches the existing token_scope resource group
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
