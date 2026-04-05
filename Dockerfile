FROM oven/bun:1.3.10-debian

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 python3-venv tini \
  && python3 -m venv /opt/venv \
  && /opt/venv/bin/pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple "litellm[proxy]" \
  && rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/venv/bin:$PATH"

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile \
  && bun -e "import Anthropic from '@anthropic-ai/sdk'; console.log('sdk-ok')"

COPY . .

RUN chmod +x /app/docker/entrypoint.sh /app/bin/claude-haha

EXPOSE 4000

ENTRYPOINT ["/usr/bin/tini", "--", "/app/docker/entrypoint.sh"]
