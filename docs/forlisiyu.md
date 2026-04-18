# 0、验证
docker run --rm -it --entrypoint /bin/bash devi-offline:1.1 -lc 'bun --version; bun -e "import Anthropic from \"@anthropic-ai/sdk\"; console.log(\"sdk-ok\")"'

# 1、启动litellm
docker run -d --name devi-litellm --network devi-net   -e DEVI_PROXY_ONLY=1   -e OPENAI_API_KEY="sk-sp-077441ba1fe8450a933953adbf86732c"   -v "$PWD/.env:/app/.env:ro"   -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro"   -p 4000:4000   --restart unless-stopped   devi-offline:1.1

# 2、启动cli
MSYS_NO_PATHCONV=1 docker run --rm -it \
    --name devi-cli \
    --network container:devi-litellm \
    -e DEVI_CLI_ONLY=1 \
    -e DEVI_WORKDIR=/workspace \
    -v "$PWD":/workspace\
    -v "$PWD/.env":/app/.env:ro \
    devi-offline:1.1

# 3、不用docker启动时ok
bun --env-file=.env ./src/entrypoints/cli.tsx