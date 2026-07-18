# Handoff for next AI — ONLYOFFICE Docker-Docs local customizations

> **Full dump of everything done/known:** see [`COMPLETE-KNOWLEDGE.md`](./COMPLETE-KNOWLEDGE.md) (Persian, comprehensive).  
> This file is the shorter English-oriented handoff; prefer `COMPLETE-KNOWLEDGE.md` when context is missing.

**Audience:** next Cursor/AI chat tab  
**Purpose:** understand what was changed *on top of* upstream ONLYOFFICE/Docker-Docs, why, and what still works / still missing — without re-discovering the same issues.

**Repo:** `E:\github\Docker-Docs` (fork/work on official Docker-Docs)  
**Upstream intent:** build multi-service / cluster images for ONLYOFFICE Docs (mainly for Helm/K8s). Non-root user `ds` (UID/GID **101**) is already upstream.

---

## TL;DR for the next agent

1. Upstream images are built from **Fedora + RPM** (not by patching `onlyoffice/documentserver`). Edition comes from `.env` → `PRODUCT_EDITION` (`""` | `-de` | `-ee`).
2. Local extras beyond upstream are mainly in commit `879880a` (+ docs under `docs/` currently staged).
3. Stack was made to run on **Windows** via Compose after CRLF and missing `image:` issues.
4. Prefer **`docs-cluster-*`** for all Docs roles in Compose; split images are optional aliases.
5. Do **not** crack license / remove connection limits. `-de` needs `license.lic` for full commercial features.
6. Dockerfile CRLF `sed` strip was discussed but is **NOT** in the current Dockerfile — reliance is on `.gitattributes` + LF scripts + rebuild.

---

## User goals (context)

- Run Docs **non-root** on Kubernetes later.
- Private registry style naming (e.g. Mohaymen registry) — base concept is still these built images.
- Custom Persian fonts under `fonts/`.
- Understand Community vs Developer (`-de`) pricing/licensing; product will be sold → Developer path (buy license), not license bypass.
- Evaluate scale (≈1000 concurrent) then purchase — no license circumvention assistance.

---

## What THIS repo is (do not confuse)

| Thing | Truth |
|-------|--------|
| `onlyoffice/documentserver` | Monolithic official image (usually root; different repo) |
| **This repo (Docker-Docs)** | Multi-stage build → `docs-cluster` / proxy / docservice / converter / utils / metrics / postgresql |
| Non-root | Upstream already sets `USER ds` (101) on Docs images |
| Paid vs free binary | `PRODUCT_EDITION=-de` downloads `onlyoffice-documentserver-de*.rpm` |
| Full paid activation | File `license.lic` under Data path — **not** produced by this repo |

RPM URL pattern:

```text
https://download.onlyoffice.com/install/documentserver/linux/onlyoffice-documentserver{EDITION}{VERSION}.{arch}.rpm
```

Example DE 9.4.1 x86_64:

`https://download.onlyoffice.com/install/documentserver/linux/onlyoffice-documentserver-de-9.4.1.x86_64.rpm`

---

## Delta vs upstream — committed local change

**Commit:** `879880a` — *Add .gitattributes for line endings, create build.ps1 … update build.yml and docker-compose.yml*

### Files changed in that commit

| File | What was added / why |
|------|----------------------|
| `.gitattributes` | Force **LF** for `*.sh`, `*.py`, Dockerfiles, yml/conf — avoid Windows CRLF baking `bash\r` into images |
| `build.ps1` | PowerShell equivalent of `build.sh` (load `.env`, BuildKit, md5 date hash, `docker compose -f build.yml build`) |
| `build.yml` | Explicit `image:` for **metrics** and **postgresql** so tags become `…/docs-metrics` and `…/docs-postgresql` |
| `docker-compose.yml` | See next section |

### `docker-compose.yml` behavioral fixes (local)

1. **`metrics.image`** → `${ACCOUNT_NAME}/${PREFIX_NAME}-metrics:${DOCKER_TAG}`  
   Upstream compose had metrics **without** `image` or `build` → Compose v2 error: *neither an image nor a build context*.
2. **`postgresql.image`** → `${ACCOUNT_NAME}/${PREFIX_NAME}-postgresql:${DOCKER_TAG}`  
   Same upstream bug.
3. **`example`** → `profiles: [example]` so default `up` does not require missing example image.
4. **`EXAMPLE_HOST_PORT=docservice:8000`** on proxy (instead of `example:3000`) so nginx can start when example service is not running (otherwise `host not found in upstream "example:3000"` and proxy restart loop).
5. **Postgres healthcheck** → `pg_isready -U myuser -d mydb` (was `-U onlyoffice`, mismatched env).

### Docs added for humans / AI (staged, may not be committed yet)

Under `docs/`:

- `fa-build-report.md` / `.html` — narrative report (this file should remain the AI handoff source of truth)
- `fa-docker-compose.html` — Compose how-to (FA RTL)
- `fa-kubernetes-helm.html` — Helm/K8s how-to (FA RTL)
- `fa-images-cluster-vs-split.md` / `.html` — deep dive why Compose uses cluster image vs Helm defaults for split names

---

## Important: what was done but NOT kept in Dockerfile

During debugging, a planned hard fix was:

```dockerfile
# After COPY entrypoints — strip Windows CRLF in image
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
        /usr/local/bin/proxy-docker-entrypoint.sh \
        /init/init-docker-entrypoint.sh && chmod +x ...
```

**Current tree:** that `RUN` is **absent** from `Dockerfile` / `Dockerfile.noplugins`.

Mitigations that *are* present:

- `.gitattributes` eol=lf
- Scripts were converted to LF on disk before successful rebuild
- Successful run after rebuild showed **no** `bash\r`; `docservice` ran as `uid=101(ds)`; `/healthcheck` → `true`

**If CRLF returns on a fresh Windows clone before attributes apply:** re-add the Dockerfile `sed` strip or enforce LF, then rebuild Docs images.

---

## Fonts (customization, content)

Directory `fonts/` (build copies into `core-fonts/custom/`):

- `B-NAZANIN.TTF`
- `IRANSansX-Regular.ttf`
- `Vazir.ttf`
- `Yekan.ttf`
- `.placeholder`

Placement is correct per upstream README; they only apply if the image was built **after** fonts were present.

---

## How to build / run (Windows)

```powershell
cd E:\github\Docker-Docs

# PowerShell:
.\build.ps1

# OR Git Bash:
./build.sh

docker compose up -d
curl http://localhost/healthcheck   # expect: true
docker compose exec docservice id   # expect: uid=101(ds)
```

- Web UI: `http://localhost` (`80:8888` on proxy)
- `.env` at last successful path used **`PRODUCT_EDITION=-de`**, `RELEASE_VERSION=-9.4.1`

Expected local images include:

- `onlyoffice/docs-cluster-de:latest` ← **used** by proxy/docservice/converter/adminpanel
- `onlyoffice/docs-utils`, `docs-metrics`, `docs-postgresql` ← used
- `docs-proxy-de` / `docs-docservice-de` / `docs-converter-de` ← often **unused** in Compose (same content as cluster; for Helm backward-compat names)

---

## Images vs containers (precise — read this)

**Image** = filesystem artifact in the registry/daemon (`onlyoffice/docs-…:tag`).  
**Container / Compose service / K8s Pod** = a *running* instance that *starts from* an image, often with overridden `command`/`entrypoint`.

They are not the same thing. You can run **4 containers from 1 image**.

### A) What each **image** is (build products)

| Image (with `-de`) | Dockerfile target | Filesystem content | Default start | Notes |
|--------------------|-------------------|--------------------|---------------|-------|
| `docs-cluster-de` | `docs` | Full Docs (nginx bits + docservice + converter + adminpanel assets, etc.) | `ENTRYPOINT docker-entrypoint.sh`, `CMD docservice` | **Canonical multi-role image** |
| `docs-proxy-de` | `proxy` | **Identical** to `docs` | `ENTRYPOINT proxy-docker-entrypoint.sh` | Alias for defaults only |
| `docs-docservice-de` | `docservice` | **Identical** to `docs` | `CMD docservice` | Alias for defaults only |
| `docs-converter-de` | `converter` | **Identical** to `docs` | `CMD converter` | Alias for defaults only |
| `docs-utils` | `utils` | K8s helper scripts / tooling | python tooling | Not the editor |
| `docs-metrics` | `metrics` | statsd + OO metrics config | statsd | Side metrics |
| `docs-postgresql` | `db` | `postgres` + `createdb.sql` | postgres entrypoint | Convenience DB image |

Upstream Dockerfile states proxy/docservice/converter stages add **no extra files** — only default execution mode differs from `docs`.

### B) What each **Compose container/service** is (runtime)

From current `docker-compose.yml` (local run):

| Compose service | Role at runtime | Image used | How role is selected |
|-----------------|-----------------|------------|----------------------|
| `proxy` | Edge nginx on host `:80` → `:8888` | **`docs-cluster-de`** | `entrypoint: proxy-docker-entrypoint.sh` |
| `docservice` | Editor API / collab | **`docs-cluster-de`** | `command: [docservice]` |
| `converter` | File conversion (often 2 replicas) | **`docs-cluster-de`** | `command: [converter]` |
| `adminpanel` | Admin UI backend | **`docs-cluster-de`** | `command: [adminpanel]` |
| `postgresql` | DB (+ schema on first init) | `docs-postgresql` | normal postgres |
| `redis` | cache | `redis:7` | — |
| `rabbitmq` | AMQP | `rabbitmq:3` | — |
| `metrics` | statsd | `docs-metrics` | — |
| `utils` | helpers | `docs-utils` | — |
| `example` | sample app (optional profile) | `docs-example` | not started by default |

So in Docker Desktop you correctly see:

- **In use:** `docs-cluster-de`, `docs-postgresql`, `docs-metrics`, `docs-utils`, …
- **Unused:** `docs-proxy-de`, `docs-docservice-de`, `docs-converter-de`  
  → built by `build.yml`, **not referenced** by compose services.

### C) Kubernetes / Helm mapping

| Workload (logical) | Must be a separate Deployment? | Must be a separate **image repository**? |
|--------------------|--------------------------------|--------------------------------------------|
| proxy | **Yes** (own lifecycle/ports) | **No** — can use `docs-cluster-de` + proxy entrypoint |
| docservice | **Yes** (scale editors) | **No** — same image + `args: [docservice]` |
| converter | **Yes** (scale converters) | **No** — same image + `args: [converter]` |

Helm chart defaults often still *name* `docs-docservice-de` / `docs-proxy-de` / `docs-converter-de` for **backward compatibility**. That is a **values convention**, not a technical requirement of Kubernetes. You may set all repositories to `docs-cluster-de`.

Deep dive: `docs/fa-images-cluster-vs-split.md`

---

## Cluster image vs split images (short)

- Always want separate **workloads/containers**.
- Do **not** always need separate **image tags**.
- Compose in this repo → one image (`cluster`) + command overrides.
- Helm defaults → may pull three tag names; overrideable to one.

---

## Postgres note

- `docs-postgresql` = official `postgres:$VERSION` + `createdb.sql` in `/docker-entrypoint-initdb.d/`.
- Production/K8s: normal Postgres ≥ **12.9** (CI tested 12–16) + one-shot Job/init of `createdb.sql` is fine; **15 is default, not mandatory**.
- Empty Postgres **without** schema → runtime DB errors. Empty Postgres **with** schema applied → OK.

---

## Known runtime warnings (not build blockers)

- `ENOENT ... license.lic` on `-de` without license → WARN; services can still start; full commercial/cluster features need purchased `license.lic` mounted under Data.
- AdminPanel may log bootstrap/setup code on first run.

---

## Explicit non-goals / do not do

- Do not remove or patch concurrent-connection / license enforcement to “test 1000 users for free.”
- Do not treat Community AGPL as a clean path for selling embedded editors in a commercial product without legal review.
- Do not assume official Hub `documentserver` image is what this repo produces.

---

## Suggested next steps for the next AI

1. Confirm `git status` — commit remaining `docs/*` if user wants them kept.
2. If user re-hits `bash\r`: reintroduce Dockerfile CRLF strip + rebuild `docs`/`proxy`/`docservice`/`converter` targets.
3. For K8s handoff: push `docs-cluster-de` (+ utils/metrics as needed) to private registry; Helm values with `runAsUser/fsGroup: 101`; DB init Job; optional `license.lic` secret/volume.
4. Keep Compose working as smoke test before cluster deploy.
5. If user asks about 1000 users: legitimate path = Developer/Enterprise trial or license + proper scaling — not RPM cracking.

---

## Quick file index

| Path | Role |
|------|------|
| `build.sh` / `build.ps1` | Build wrapper |
| `build.yml` | Compose build definitions + image tags |
| `docker-compose.yml` | Local run (patched for Windows/compose v2) |
| `.gitattributes` | LF enforcement for scripts |
| `.env` | Edition, version, JWT, account/prefix/tag |
| `fonts/` | Custom fonts baked at build |
| `docs/fa-*.md|html` | Human + AI documentation (FA) |

---

*Last verified in conversation when local `docker compose up` returned healthcheck `true` and `uid=101(ds)` after rebuild with LF scripts.*
