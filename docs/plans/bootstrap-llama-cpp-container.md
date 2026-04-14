# Bootstrap llama-cpp-container

## Context

The `clcollins/llama-cpp-container` repo was empty. This plan bootstrapped it
as a containerized `llama.cpp` runtime following the exact conventions and
patterns established in `clcollins/ollama-container`. The new repo ships with
a full CI suite from day one: build validation, lint checks, Kubernetes
manifest validation, plan-doc enforcement, and OCI label validation — all
running inside a shared CI container image both locally (`make ci-all`) and
in GitHub Actions (fan-out to parallel jobs sharing one built artifact).

Decisions:

- **Binary source**: prebuilt release asset from `ggml-org/llama.cpp`
  releases (mirrors ollama-container's tarball-curl pattern). Pinned to
  `LLAMA_CPP_VERSION=b8783`.
- **Acceleration**: CPU-only. GPU variants (CUDA, Vulkan, ROCm) deferred to
  follow-up plans.
- **Kubernetes manifests**: full `deploy/` directory + root `llama.yaml`.

## Repository Layout Created

```
llama-cpp-container/
├── .github/workflows/
│   ├── ci.yaml
│   └── image-build-push.yaml
├── .containerignore
├── .gitignore
├── .markdownlint.yaml
├── .yamllint.yaml
├── CLAUDE.md
├── CONVENTIONS.md
├── Containerfile
├── LICENSE
├── Makefile
├── README.md
├── llama.yaml
├── deploy/
│   ├── llama.Namespace.yaml
│   ├── llama.PersistentVolumeClaim.yaml
│   ├── llama.Deployment.yaml
│   └── llama.Service.yaml
├── docs/plans/
│   └── bootstrap-llama-cpp-container.md   (this file)
├── examples/
│   └── ask.py
└── test/
    ├── .containerignore
    ├── Containerfile.ci
    └── scripts/
        └── check-containerfile-tags.sh
```

## Key Adaptations for llama.cpp

### Containerfile

- `FROM registry.fedoraproject.org/fedora-minimal:43 as deps` (pinned).
- Installs `tar`, `gzip`, `libcurl`, `libgomp` (runtime deps for llama.cpp's
  prebuilt Ubuntu binaries).
- `ARG LLAMA_CPP_VERSION=b8783` — pinned release tag.
- Arch-aware download: `x64` → `x86_64`, `arm64` → `aarch64`.
- Asset URL:
  `https://github.com/ggml-org/llama.cpp/releases/download/${VERSION}/llama-${VERSION}-bin-ubuntu-${ARCH}.tar.gz`
- Extracts `build/bin/llama-*` into `/usr/local/bin/` and `build/bin/*.so`
  into `/usr/local/lib/`; runs `ldconfig`.
- `ENV LLAMA_ARG_HOST=0.0.0.0 LLAMA_ARG_PORT=8080`.
- `EXPOSE 8080`; `ENTRYPOINT ["llama-server"]`.
- All 5 required OCI labels present.

### Makefile

Copies ollama-container's Makefile with:

- `IMAGE_NAME = "llama-cpp"`
- `CI_IMAGE = "llama-cpp-ci"`
- `LLAMA_CPP_VERSION` variable, threaded into `BUILD_ARGS`
- `kubernetes-validate` target validates both `deploy/` and `llama.yaml`

### test/Containerfile.ci and test/scripts/check-containerfile-tags.sh

Mirror ollama-container's CI image and tag validation script. Same pinned
tool versions (`yamllint==1.38.0`, `ruff==0.15.9`,
`markdownlint-cli2@0.22.0`, `checkmake 0.2.2`, `kubeconform v0.6.7`,
`ShellCheck`). The script enforces the trusted-registry allowlist and
forbids `:latest`.

### GitHub Workflows

- `ci.yaml`: fan-out pattern. `ci-image` job builds + uploads CI image;
  parallel downstream jobs each run one `make <target>`. Includes a
  host-side `image-build` job that builds the Containerfile, runs
  `llama-server --version`, and validates all 5 OCI labels.
- `image-build-push.yaml`: multi-arch (amd64 + arm64) build with QEMU,
  manifest list push to `quay.io/${QUAY_REPOSITORY}` on main / `v*` tags.

## Full CI Suite

Every check required by `CONVENTIONS.md` is wired up:

- [x] YAML lint — yamllint
- [x] Markdown lint — markdownlint-cli2
- [x] Makefile lint — checkmake
- [x] Containerfile check — tag + registry validation
- [x] Kubernetes validation — kubeconform on `deploy/` + `llama.yaml`
- [x] Python lint — ruff check + format on `examples/`
- [x] Shell lint — shellcheck on `test/scripts/*.sh`
- [x] Documentation check — plan documents exist in `docs/plans/`
- [x] Container image build — `podman build` succeeds
- [x] Build smoke test — `llama-server --version` in the built image
- [x] OCI label validation — all 5 labels present

## Known Risks / Items to Verify

1. **glibc compatibility**: llama.cpp's Ubuntu-built binaries link against
   Ubuntu's glibc. `fedora-minimal:43` ships a newer glibc and should be
   forward-compatible. The `RUN llama-server --version` line at the end of
   the Containerfile validates this at build time — if incompatible, the
   build fails immediately.
2. **Release asset structure**: this plan assumes the tarball contains
   `build/bin/llama-*` and `build/bin/*.so`. Verify on the first `make
   build`; adjust the `cp` paths in the Containerfile if the archive layout
   differs.
3. **Models are not bundled**: users must mount a GGUF file. The Deployment
   expects `/models/model.gguf` — operators must either rename their model
   or edit `LLAMA_ARG_MODEL` in `deploy/llama.Deployment.yaml`.

## Verification (post-merge)

1. `make ci-all` passes locally.
2. `make build && podman run --rm --entrypoint llama-server llama-cpp
   --version` prints a version.
3. With a small GGUF model: `podman run --rm -p 8080:8080 -v
   ./models:/models:Z llama-cpp --model /models/<tiny>.gguf` and `curl
   localhost:8080/health` returns 200.
4. `podman kube play llama.yaml` succeeds.
5. All 10 CI jobs pass on the initial PR.
6. `image-build-push.yaml` produces a multi-arch manifest on merge to
   `main`.
