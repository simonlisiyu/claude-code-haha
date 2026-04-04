FROM oven/bun:1-debian

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 python3-pip tini \
  && python3 -m pip install --no-cache-dir "litellm[proxy]" \
  && rm -rf /var/lib/apt/lists/*

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .

RUN chmod +x /app/docker/entrypoint.sh /app/bin/claude-haha

EXPOSE 4000

ENTRYPOINT ["/usr/bin/tini", "--", "/app/docker/entrypoint.sh"]
