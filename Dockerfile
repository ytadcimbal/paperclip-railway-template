# СТАДИЯ 1: Сборка Paperclip из исходников
FROM node:22-bookworm-slim AS paperclip-build
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*
RUN corepack enable

ARG PAPERCLIP_REPO=https://github.com/paperclipai/paperclip.git
ARG PAPERCLIP_REF=v2026.416.0

WORKDIR /paperclip
RUN git clone --depth 1 --branch "${PAPERCLIP_REF}" "${PAPERCLIP_REPO}" .

# --- PATCH: Регистрация адаптера Hermes ---
RUN pnpm --filter @paperclipai/server add hermes-paperclip-adapter
COPY register-adapter.mjs /register-adapter.mjs
RUN node /register-adapter.mjs
# --- END PATCH ---

RUN pnpm install --frozen-lockfile
RUN pnpm --filter @paperclipai/ui build
RUN pnpm --filter @paperclipai/plugin-sdk build
RUN pnpm --filter @paperclipai/server build
RUN test -f server/dist/index.js

# СТАДИЯ 2: Финальный образ (Runtime)
FROM node:22-bookworm-slim
ENV NODE_ENV=production
ENV CLAUDE_CODE_BUBBLEWRAP=1
ENV HOME=/paperclip \
    PAPERCLIP_INSTANCE_ID=default \
    PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
    OPENCODE_ALLOW_ALL_MODELS=true

# Устанавливаем системные зависимости, включая Python для Hermes
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-client \
    ripgrep \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*
RUN corepack enable

WORKDIR /app
COPY --from=paperclip-build /paperclip /app

WORKDIR /wrapper
COPY package.json /wrapper/package.json
RUN npm install --omit=dev && npm cache clean --force
COPY src /wrapper/src
COPY scripts/entrypoint.sh /wrapper/entrypoint.sh
COPY scripts/bootstrap-ceo.mjs /wrapper/template/bootstrap-ceo.mjs
RUN chmod +x /wrapper/entrypoint.sh

# Устанавливаем JS-инструменты
RUN npm install --global --omit=dev \
    @anthropic-ai/claude-code@latest \
    @openai/codex@latest \
    opencode-ai \
    tsx

# Устанавливаем Hermes Agent через Python (Pip)
# Флаг --break-system-packages нужен для Debian 12+
RUN pip3 install --no-cache-dir --break-system-packages hermes-agent

RUN mkdir -p /paperclip \
    && chown -R node:node /app /paperclip /wrapper

EXPOSE 3100
ENTRYPOINT ["/wrapper/entrypoint.sh"]
CMD ["node", "/wrapper/src/server.js"]