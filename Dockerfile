# 第一阶段：编译构建阶段，仅用于生成可执行文件
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV PATH="/root/.cargo/bin:$PATH"

# 仅安装编译必需依赖，不携带冗余运行库
RUN apt update && apt install -y --no-install-recommends \
    build-essential libssl-dev libwebkit2gtk-4.1-dev curl git \
    ca-certificates \
    && update-ca-certificates \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# 替换原有Node.js安装步骤
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    . "$HOME/.nvm/nvm.sh" && \
    nvm install 24 && corepack enable pnpm

# 克隆源码并执行生产构建
RUN git clone https://github.com/crynta/terax-ai.git /opt/terax-ai
WORKDIR /opt/terax-ai
RUN pnpm install && pnpm tauri build --bundles none

# 第二阶段：轻量化运行阶段，仅保留运行必需组件
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8

# 仅安装Terax运行必需的最小依赖
RUN apt update && apt install -y --no-install-recommends \
    libwebkit2gtk-4.0-37 libgtk-3-0 libayatana-appindicator3-1 \
    && rm -rf /var/lib/apt/lists/*

# 仅从构建阶段拷贝最终生成的可执行文件，不携带源码和编译缓存
COPY --from=builder /opt/terax-ai/src-tauri/target/release/terax /usr/local/bin/terax

EXPOSE 8080
CMD ["terax", "--no-sandbox", "--port", "8080"]
