# AstroLumina-Helm

Helm chart for the AstroLumina platform (frontend + astrology / booking /
payment APIs). One chart, one release per environment — the differences
between dev, staging and production live in the values files. Rendered
output is functionally identical to the former Kustomize manifests in
`AstroLumina-Kubernetes` (verified by an automated diff, see Validation).

## Layout

```text
charts/astrolumina/
  Chart.yaml
  values.yaml                  # shared service catalog (images, resources, env wiring)
  values-dev.yaml              # development (NodePort, no Traefik)
  values-staging.yaml          # staging (blue/green, HTTP Traefik)
  values-production.yaml       # production (blue/green, HTTPS + dashboard auth)
  templates/
    namespace.yaml             # 00 equivalent
    ghcr-secret.yaml           # 01 placeholder (real secret is imperative, see below)
    placeholder-secrets.yaml   # 02 placeholders (first-boot values until Doppler syncs)
    doppler-secrets.yaml       # 03 DopplerSecret sync wiring
    deployments.yaml           # 10/20/30/40 (x blue/green on staging/prod)
    services.yaml              # NodePorts on dev, *-live ClusterIP on staging/prod
    hpa.yaml                   # 70
    networkpolicy.yaml         # 60 (permissive on dev, strict otherwise)
    middlewares.yaml           # 51 (staging/prod only)
    ingressroute.yaml          # 52 (staging/prod only)
    NOTES.txt                  # post-install hints
```

## Usage

One release per environment, each with its own values file:

```bash
helm install astrolumina-dev ./charts/astrolumina \
  -f charts/astrolumina/values-dev.yaml

helm install astrolumina-staging ./charts/astrolumina \
  -f charts/astrolumina/values-staging.yaml

helm install astrolumina-prod ./charts/astrolumina \
  -f charts/astrolumina/values-production.yaml
```

Dry-run against the old manifests any time:

```bash
helm template astrolumina-dev ./charts/astrolumina \
  -f charts/astrolumina/values-dev.yaml
```

Blue-green switch (staging/production — flips the 4 `*-live` selectors,
exactly like editing `53-live-services.yaml` by hand):

```bash
helm upgrade astrolumina-staging ./charts/astrolumina \
  -f charts/astrolumina/values-staging.yaml \
  --set blueGreen.liveColor=green
```

Pin image tags from Doppler without editing values (tags live in Doppler
as `*_DOCKER_IMAGE_TAG`, same flow as the old `kubectl set image` step):

```bash
helm upgrade astrolumina-prod ./charts/astrolumina \
  -f charts/astrolumina/values-production.yaml \
  --set image.tag=<tag-from-doppler>
```

## First boot on an empty cluster (3 phases, same as before)

1. Install the release — pods boot on the placeholder Secrets.
2. Create the one-time token Secret and let the Doppler operator sync
   real values (token name per env: `doppler-token-dev` / `-stg` / `-prd`;
   see `NOTES.txt` output after install for the exact commands).
3. After the sync is verified, phase the placeholders out without
   uninstalling:

```bash
helm upgrade <release> ./charts/astrolumina -f charts/astrolumina/<values-file> \
  --set placeholderSecretsEnabled=false
```

## NOT in this chart (imperative, once per cluster rebuild)

- The `doppler-token-*` ServiceToken Secret in `doppler-operator-system`.
- The real `ghcr-secret` docker-registry Secret (chart ships a placeholder
  only — a pull secret cannot be synced by the Doppler operator).
- The `traefik-dashboard-auth` Secret in `astrolumina-prod` (htpasswd
  `users` line for the dashboard basicAuth middleware).
- The RKE2 `HelmChartConfig` enabling Traefik + the `letsencrypt`
  certResolver (production prerequisite).

## Deliberate normalizations vs the Kustomize originals

- Placeholder Secrets and Deployments use `app.kubernetes.io/component`
  everywhere; the old dev Secrets used `app.kubernetes.io/name` instead.
- Rendered `stringData` values are always quoted; parsed values are equal.
- Doppler sync-key order follows staging/production (K8s URLs last);
  the old dev files listed them mid-list. Order is irrelevant to the
  operator; key sets are identical.
- The stale `# 3 replicas` comment on staging Deployments (which actually
  run 1 replica) was dropped; replicas come from values.

## Validation

`helm lint` passes for all three values files, and every rendered object
was compared field-by-field against the original manifests: resource
inventory, replicas, images, full `secretKeyRef` env wiring (name/key/
optional), probes, resources, affinity, selectors, labels, service ports,
HPA bounds/metrics/targets, Doppler sync key sets, placeholder values,
NetworkPolicy, middlewares and IngressRoutes — all equal.
