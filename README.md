# nexus-railway

Sonatype Nexus Repository Community Edition 3.97.3 wrapper image for Railway.

- One service, one volume mounted at `/nexus-data`.
- `NEXUS_SECURITY_INITIAL_PASSWORD` (set by the template with a generated secret) becomes the `admin` password on first boot, so there is no `admin.password` file to fetch and no onboarding wizard password step.
- Jetty binds the `PORT` Railway injects.
- The JVM heap (40%) and direct memory (30%) are sized from the container's cgroup limit, each capped at the 2703 MB Sonatype documents; `NEXUS_HEAP_MB` and `NEXUS_DIRECT_MB` override.
- The root-owned Railway volume is chowned to uid 200 once, then the process drops privileges with `su-exec`.
- The Community Edition EULA is NOT accepted by this image. Accepting it is the deployer's own act (`POST /service/rest/v1/system/eula`), see the template README.

Built by `.github/workflows/publish.yml` to `ghcr.io/bon5co/nexus-railway`. Base: `sonatype/nexus3:3.97.3` pinned by digest.
