# Agent Guidance — llama-cpp-container

This repository packages [llama.cpp](https://github.com/ggml-org/llama.cpp)
as a container image running the `llama-server` OpenAI-compatible HTTP
server. It follows the project conventions defined in
[`CONVENTIONS.md`](CONVENTIONS.md) verbatim — always read that file first.

## Repository Entry Points

- **Local verification**: `make ci-all` — builds the CI container image, then
  runs every lint and validation check inside it serially. This is the single
  command that mirrors what GitHub Actions runs in parallel.
- **Application build**: `make build` — builds the `llama-cpp` application
  image from `Containerfile` with the pinned `LLAMA_CPP_VERSION` baked in.
- **Local run**: `podman run --rm -p 8080:8080 -v ./models:/models:Z llama-cpp
  --model /models/<your>.gguf` — llama.cpp uses GGUF model files, not
  bundled in the image.

## Repository Layout

| Path | Purpose |
| ---- | ------- |
| `Containerfile` | Application image; downloads pinned llama.cpp release |
| `Makefile` | Build + CI entry points; see `CONVENTIONS.md` for required targets |
| `test/Containerfile.ci` | CI container with all lint tools pre-installed |
| `test/scripts/check-containerfile-tags.sh` | Registry/tag validation for Containerfiles |
| `.github/workflows/ci.yaml` | Fan-out CI: one shared CI image, parallel lint jobs |
| `.github/workflows/image-build-push.yaml` | Multi-arch (amd64+arm64) push to Quay |
| `deploy/` | Kubernetes manifests (Namespace, PVC, Deployment, Service) |
| `llama.yaml` | Podman `play kube` manifest for single-pod local runs |
| `docs/plans/` | Every change has an associated plan document here |
| `examples/ask.py` | Client example hitting `/v1/chat/completions` |

## CI Model

All lint and validation checks run inside the `llama-cpp-ci` container image
built from `test/Containerfile.ci`. In GitHub Actions, one job builds that
image and uploads it as an artifact; downstream jobs download + load it and
run a single `make <target>` each. This matches the pattern in
`clcollins/ollama-container` and guarantees local (`make ci-all`) and remote
environments are identical.

The `image-build` job runs on the host runner (not inside the CI image)
because it needs the container engine itself to build the application image.

## Conventions Recap (see `CONVENTIONS.md` for the full text)

- Container engine: **podman** (use `CONTAINER_SUBSYS` var to switch).
- Base images: `registry.fedoraproject.org/fedora-minimal:43` for the app,
  `:42` for CI — always pinned.
- Pinned `LLAMA_CPP_VERSION` ARG in the Containerfile. Bump deliberately;
  every bump is a plan document in `docs/plans/`.
- All five required OCI labels (`title`, `description`, `revision`,
  `version`, `source`) — enforced by the `image-build` CI job.
- Feature branches only; never commit to `main`. DCO sign-off on commits.

## When Making Changes

1. Write a plan document in `docs/plans/` before implementing significant
   changes. Use a descriptive filename (no numeric prefixes).
2. Keep `Containerfile` and `test/Containerfile.ci` pinned to specific
   versions; the `containerfile-check` CI target enforces this.
3. Run `make ci-all` locally before pushing — it will catch everything CI
   catches, because it runs the same container and the same `make` targets.
4. After pushing, verify every CI job passes green.
