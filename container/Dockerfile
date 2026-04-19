# NanoClaw Agent Container
# Runs Claude Agent SDK in isolated Linux VM with browser automation

FROM node:22-slim

# Chromium version pin — see explanation below
# Override at build: ./container/build.sh --build-arg CHROMIUM_VERSION=<version>
# Empty value means "latest available" (drift risk — see below)
ARG CHROMIUM_VERSION=147.0.7727.101-1~deb12u1

# Why pin: telegram-ads session is tied to browser fingerprint. If chromium
# version drifts on rebuild, ads.telegram.org sees a "new device" and forces
# re-authorization. Pinning keeps the fingerprint stable across rebuilds.
# When you need to upgrade: bump ARG, rebuild, re-auth once via /telegram-ads-auth.
# If the pinned version disappears from Debian bookworm repo, the build will
# fail with "E: Version ... not found" — update ARG to current version.

# Install system dependencies. Chromium is pinned via ARG above — if the ARG is
# empty, we install "latest", otherwise "chromium=<ver>". We use an intermediate
# shell variable to avoid expanding the version twice in the apt-get args list.
RUN apt-get update && \
    CHROMIUM_PKG="${CHROMIUM_VERSION:+chromium=${CHROMIUM_VERSION}}" && \
    CHROMIUM_PKG="${CHROMIUM_PKG:-chromium}" && \
    apt-get install -y \
    "$CHROMIUM_PKG" \
    fonts-liberation \
    fonts-noto-color-emoji \
    libgbm1 \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libcups2 \
    libdrm2 \
    libxshmfence1 \
    curl \
    git \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-rus \
    tesseract-ocr-eng \
    ffmpeg \
    python3 \
    python3-pip \
    python3-pil \
    && apt-mark hold chromium \
    && rm -rf /var/lib/apt/lists/*

# Install rembg for logo/background removal (thumbnail generation)
# --break-system-packages needed for Debian 12 PEP 668
RUN pip3 install --break-system-packages --no-cache-dir rembg[cpu] onnxruntime numpy

# Set Chromium path for agent-browser
ENV AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

# Install agent-browser and claude-code globally
RUN npm install -g agent-browser @anthropic-ai/claude-code

# Create app directory
WORKDIR /app

# Copy package files first for better caching
COPY agent-runner/package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY agent-runner/ ./

# Build TypeScript
RUN npm run build

# Create workspace directories
RUN mkdir -p /workspace/group /workspace/global /workspace/extra /workspace/ipc/messages /workspace/ipc/tasks /workspace/ipc/input

# Create entrypoint script
# Container input (prompt, group info) is passed via stdin JSON.
# Credentials are injected by the host's credential proxy — never passed here.
# Follow-up messages arrive via IPC files in /workspace/ipc/input/
# Apple Container only supports directory mounts (VirtioFS), so .env cannot be
# shadowed with a host-side /dev/null file mount. Instead the entrypoint starts
# as root, uses mount --bind to shadow .env, then drops to the host user via setpriv.
RUN printf '#!/bin/bash\nset -e\n\n# Shadow .env so the agent cannot read host secrets (requires root)\nif [ "$(id -u)" = "0" ] && [ -f /workspace/project/.env ]; then\n  mount --bind /dev/null /workspace/project/.env\nfi\n\n# Compile agent-runner\ncd /app && npx tsc --outDir /tmp/dist 2>&1 >&2\nln -s /app/node_modules /tmp/dist/node_modules\nchmod -R a-w /tmp/dist\n\n# Capture stdin (secrets JSON) to temp file\ncat > /tmp/input.json\n\n# Drop privileges if running as root (main-group containers)\nif [ "$(id -u)" = "0" ] && [ -n "$RUN_UID" ]; then\n  chown "$RUN_UID:$RUN_GID" /tmp/input.json /tmp/dist\n  exec setpriv --reuid="$RUN_UID" --regid="$RUN_GID" --clear-groups -- node /tmp/dist/index.js < /tmp/input.json\nfi\n\nexec node /tmp/dist/index.js < /tmp/input.json\n' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# Set ownership to node user (non-root) for writable directories
RUN chown -R node:node /workspace && chmod 777 /home/node

# Set working directory to group workspace
WORKDIR /workspace/group

# Entry point reads JSON from stdin, outputs JSON to stdout
ENTRYPOINT ["/app/entrypoint.sh"]
