FROM registry.fedoraproject.org/fedora-minimal:43 as deps

RUN microdnf install --assumeyes tar gzip libcurl libgomp \
  && microdnf clean all \
  && rm -rf /var/cache/yum

FROM deps
LABEL author "Chris Collins <collins.christopher@gmail.com>"
LABEL com.github.containers.toolbox="true"

ARG GIT_HASH
ARG LLAMA_CPP_VERSION=b8783

LABEL toolbox-llama-cpp-version ${GIT_HASH}

LABEL org.opencontainers.image.title="llama-cpp-container"
LABEL org.opencontainers.image.description="Containerized llama.cpp inference server"
LABEL org.opencontainers.image.revision=${GIT_HASH}
LABEL org.opencontainers.image.version=${GIT_HASH}
LABEL org.opencontainers.image.source="https://github.com/clcollins/llama-cpp-container"

ENV LLAMA_ARG_HOST=0.0.0.0
ENV LLAMA_ARG_PORT=8080

RUN mkdir -p /models \
  && chmod -R 777 /models

RUN arch="$(uname -m)" \
  && case "$arch" in \
       x86_64) target_arch="x64" ;; \
       aarch64|arm64) target_arch="arm64" ;; \
       *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
     esac \
  && curl -fsSL "https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VERSION}/llama-${LLAMA_CPP_VERSION}-bin-ubuntu-${target_arch}.tar.gz" -o /tmp/llama.tar.gz \
  && mkdir -p /tmp/llama \
  && tar -C /tmp/llama -xzf /tmp/llama.tar.gz \
  && cp /tmp/llama/llama-${LLAMA_CPP_VERSION}/llama-* /usr/local/bin/ \
  && cp /tmp/llama/llama-${LLAMA_CPP_VERSION}/lib*.so* /usr/lib64/ \
  && ldconfig \
  && rm -rf /tmp/llama /tmp/llama.tar.gz

WORKDIR /models

RUN llama-server --version

EXPOSE 8080

ENTRYPOINT ["llama-server"]
