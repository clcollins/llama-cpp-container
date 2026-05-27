# llama-cpp-container

A containerized [llama.cpp](https://github.com/ggml-org/llama.cpp) inference
server, packaged on `fedora-minimal` and serving the OpenAI-compatible
`llama-server` HTTP API on port `8080`.

This repository follows the conventions defined in
[`CONVENTIONS.md`](CONVENTIONS.md).

## Quick Start

### Build

```bash
make build
```

### Run with a local model

Download a GGUF model into a `./models/` directory, then:

```bash
podman run --rm -p 8080:8080 -v ./models:/models:Z llama-cpp \
  --model /models/<your-model>.gguf
```

### Query the server

```bash
curl http://localhost:8080/health

curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

Or use the included Python example:

```bash
python examples/ask.py "Why is the sky blue?"
```

## Configuration

`llama-server` is configurable via CLI flags and environment variables. The
image pre-sets:

- `LLAMA_ARG_HOST=0.0.0.0`
- `LLAMA_ARG_PORT=8080`

Pass any additional `llama-server` flags as container arguments:

```bash
podman run --rm -p 8080:8080 -v ./models:/models:Z llama-cpp \
  --model /models/<model>.gguf \
  --ctx-size 4096 \
  --n-gpu-layers 0
```

See `llama-server --help` inside the container for the complete flag list.

## Kubernetes

Manifests in `deploy/` provide a minimal single-replica Deployment with a
PVC-backed `/models` volume. Apply with:

```bash
kubectl apply -f deploy/
```

Before applying, edit `deploy/llama.Deployment.yaml` to set
`LLAMA_ARG_MODEL` to the path of your GGUF file inside the PVC.

For local single-pod runs with podman:

```bash
podman kube play llama.yaml
```

## Development

All CI checks run in a dedicated container image. The local entry point is:

```bash
make ci-all
```

This builds `test/Containerfile.ci` and runs every lint/validation check
serially inside it. GitHub Actions runs the same checks in parallel on
every PR — see [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml).

Individual checks:

```bash
make yaml-lint
make markdown-lint
make makefile-lint
make containerfile-check
make kubernetes-validate
make python-lint
make shellcheck-lint
make docs-check
```

See [`CLAUDE.md`](CLAUDE.md) for agent-oriented guidance and
[`CONVENTIONS.md`](CONVENTIONS.md) for the full project standards.

## Versioning

The Containerfile pins `LLAMA_CPP_VERSION` to a specific
[`ggml-org/llama.cpp` release tag](https://github.com/ggml-org/llama.cpp/releases).
Bumping this version is done deliberately via a plan document in
`docs/plans/`.

## License

See [LICENSE](LICENSE).
