# Devi 内网部署操作说明（Docker 镜像 tar）

本文说明在**从指定对象存储获取镜像 tar 后**，在内网环境完成导入、配置与运行的步骤。内容与主仓库 [README.md](../../README.md) 中「离线 Docker 部署」一致并展开为可执行清单。

<p align="right"><a href="../../README.md">返回 README</a></p>

---

## 1. 整体说明

| 场景 | 说明 |
|------|------|
| 适用 | 默认从 **阿里云 OSS** 拉取官方打包的 tar；若目标机完全隔离，可在能访问 OSS 的跳板机下载后再拷贝进内网 |
| 镜像 tar（OSS） | `oss://bdp-pkgs/lsy/package/dev-cli/devi-offline-1.1.tar` |
| 镜像名（示例） | `devi-offline:1.1`（以 `docker load` 后 `docker images` 显示为准；若 TAG 不同，下文命令中请改用实际 TAG） |
| 配置文件模板 | 可选同版本源码中的 `.env.example`、`litellm_config.example.yaml`（也可从导入后的镜像内取出，见下文） |

---

## 2. 前置条件

- 已安装 **Docker**（或兼容的 containerd + nerdctl，命令与本文以 Docker 为准）。
- **磁盘空间**：镜像体积较大，导入前预留足够空间（建议 ≥ 15GB 余量，按实际 tar 大小调整）。
- **Linux 宿主机内核（若使用交互式 CLI）**：容器内 CLI 基于 **Bun**，与宿主机共享内核。Linux 上建议内核 **≥ 5.6**（最低 **≥ 5.1**）。过旧内核（如 CentOS 7 默认 `3.10.x`）上 LiteLLM 通常可运行，**交互 CLI 可能直接退出**。详见 [Bun 安装说明](https://bun.com/docs/installation)。
- **密钥**：按你在 `litellm_config.yaml` 中配置的上游模型，准备对应 API Key（如 `OPENAI_API_KEY`、`DASHSCOPE_API_KEY` 等），**不要**把真实密钥写入镜像，通过 `docker run -e` 或挂载的 `.env` 注入。

---

## 3. tar包镜像

### 3.1 第一步：从阿里云 OSS 下载 tar

对象路径：

```text
oss://bdp-pkgs/lsy/package/dev-cli/devi-offline-1.1.tar
```

在已安装并配置好 **ossutil**、且对 Bucket `bdp-pkgs` 具备**读权限**的机器上执行（需使用贵司下发的 AccessKey / RAM 角色等，按阿里云文档完成 `ossutil config`）：

```bash
ossutil cp oss://bdp-pkgs/lsy/package/dev-cli/devi-offline-1.1.tar .
```

也可在 **阿里云控制台** → 对象存储 OSS → 进入对应 Bucket 与路径 → 下载 `devi-offline-1.1.tar` 到本地。

若部署机**不能直连 OSS**，请先在可访问 OSS 的环境下载该文件，再通过 U 盘、堡垒机文件通道等方式传到目标服务器后再执行下一小节。

### 3.2 第二步：导入 Docker

在 tar 所在目录执行：

```bash
docker load -i devi-offline-1.1.tar
```

确认镜像（注意核对 **TAG** 是否与下文 `devi-offline:1.1` 一致，不一致则全局替换为实际 TAG）：

```bash
docker images | grep devi-offline
```

---

## 4. 准备配置

在宿主机上选定一个**工作目录**（例如 `/data/app/devi`），后续所有 `docker run` 的 `-v` 挂载都相对于该目录。

### 4.1 从镜像内复制模板到当前目录：

```bash
mkdir -p /data/app/devi && cd /data/app/devi

docker run --rm --entrypoint cat devi-offline:1.1 /app/.env.example > .env
docker run --rm --entrypoint cat devi-offline:1.1 /app/litellm_config.example.yaml > litellm_config.yaml
```

### 4.2 内网 OpenAI 兼容大模型：`litellm_config.yaml` 与 `.env`

下面给出一份**内网 OpenAI 兼容**的完整示例（在镜像模板基础上改 `api_base`、`model_name` / `model` 即可）。

**`litellm_config.yaml` 示例（内网网关）**

```yaml
# 基于 litellm_config.example.yaml：仅改 model_name、api_base、model；api_key 按是否需要密钥二选一

model_list:
  - model_name: qwen3-8b
    litellm_params:
      model: qwen3-8b
      api_base: http://10.0.0.50:8000/v1
      # 需要密钥时（与 docker run -e 或 .env 中变量名一致）：
      api_key: os.environ/INTERNAL_LLM_API_KEY
      # 不需要密钥时，可改为占位（多数内网推理服务会忽略）：
      # api_key: "not-used"

litellm_settings:
  drop_params: true
```

**`.env` 示例（与 `.env.example`「OpenAI（通过 LiteLLM 代理）」块对应）**

```env
# CLI → 本机 LiteLLM（单容器）；双容器 CLI 请改为 ANTHROPIC_BASE_URL=http://devi-litellm:4000
ANTHROPIC_AUTH_TOKEN=sk-anything
ANTHROPIC_BASE_URL=http://127.0.0.1:4000
ANTHROPIC_MODEL=qwen3-8b
ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3-8b
ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3-8b
ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3-8b
API_TIMEOUT_MS=3000000

DISABLE_TELEMETRY=1
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```
---

## 5. 运行模式（三选一）

以下命令均在**配置目录**下执行（`cd /data/app/devi`），请按 §4.2 决定是否在 `docker run` 中增加 `-e`。**勿**在文档/工单中粘贴明文密钥。

### 模式 A：单容器 — LiteLLM + 交互 CLI（同一终端）

适合一人一台机、希望一条命令起全栈。

```bash
docker run --rm -it \
  --name devi \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -p 4000:4000 \
  devi-offline:1.1
```

`.env` 中需指向容器内的代理，例如：

```env
ANTHROPIC_BASE_URL=http://127.0.0.1:4000
```

（模型名等与其余变量见 [环境变量说明](./env-vars.md)、[第三方模型](./third-party-models.md)。）

### 模式 B：仅 LiteLLM 代理（对外暴露 4000）

适合只提供 OpenAI 兼容网关，或 CLI 在别的机器/容器连接本机 `4000`。

```bash
docker run -d --name devi-litellm \
  -e DEVI_PROXY_ONLY=1 \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -p 4000:4000 \
  --restart unless-stopped \
  devi-offline:1.1
```

健康检查示例：

```bash
curl -sS http://127.0.0.1:4000/health/liveliness
```

### 模式 C：双容器 — 代理常驻 + 独立交互 CLI + 挂载业务代码

适合代理长期运行，开发机多次进入 CLI，且工作区为独立 Git 仓库。

**（1）创建网络（每台主机执行一次即可）**

```bash
docker network create devi-net 2>/dev/null || true
```

**（2）终端 A：启动 LiteLLM**

```bash
docker run -d --name devi-litellm --network devi-net \
  -e DEVI_PROXY_ONLY=1 \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -p 4000:4000 \
  --restart unless-stopped \
  devi-offline:1.1
```

**（3）终端 B：启动 CLI（替换项目路径与模型名）**

```bash
docker run --rm -it --name devi-cli --network devi-net \
  -e DEVI_CLI_ONLY=1 \
  -e DEVI_WORKDIR=/workspace \
  -e ANTHROPIC_BASE_URL=http://devi-litellm:4000 \
  -e ANTHROPIC_AUTH_TOKEN=sk-anything \
  -e ANTHROPIC_MODEL=qwen3.5-plus \
  -e ANTHROPIC_DEFAULT_SONNET_MODEL=qwen3.5-plus \
  -e ANTHROPIC_DEFAULT_HAIKU_MODEL=qwen3.5-plus \
  -e ANTHROPIC_DEFAULT_OPUS_MODEL=qwen3.5-plus \
  -v "$PWD/.env:/app/.env:ro" \
  -v "/path/to/your/project:/workspace:rw" \
  devi-offline:1.1
```

要点：

- CLI 容器必须与代理在同一网络：`--network devi-net`。
- `ANTHROPIC_BASE_URL` 使用**容器名** `http://devi-litellm:4000`，**不要**写 `localhost`（在 CLI 容器内指向自身）。
- `ANTHROPIC_*_MODEL` 必须与 `litellm_config.yaml` 中的 `model_name` 一致。

**（4）停止代理（CLI 退出后若使用 `--rm` 会自动删除）**

```bash
docker stop devi-litellm && docker rm devi-litellm
```
---

## 6. 常见问题（内网场景）

| 现象 | 处理方向 |
|------|----------|
| 交互 CLI 立刻退出 | ① 核对宿主机内核是否满足 Bun 要求；② **不要**使用 `docker run ... \| tee`，避免 stdout 非 TTY；③ `.env` 中删除或注释仅在宿主机有效的 **`CALLER_DIR`**；④ Windows 可尝试 `winpty docker run -it ...` 或 PowerShell。详见 [README — 交互 CLI 秒退](../../README.md#快速开始)。 |
| 双容器 CLI 连不上模型 | 确认 `ANTHROPIC_BASE_URL=http://devi-litellm:4000`、网络名一致、代理容器名为 `devi-litellm` 且已 `docker ps` 为运行中。 |
| API 返回非 Anthropic JSON | `ANTHROPIC_BASE_URL` 必须指向 **Anthropic Messages 兼容**端点；经 LiteLLM 转换时检查路由与模型名。参见 [FAQ](./faq.md) 与 [第三方模型](./third-party-models.md)。 |
| 仅代理正常、CLI 不可用 | 在旧内核机器上可只部署**模式 B**，将 `4000` 暴露给内网其它**新内核**主机上的 CLI 或客户端使用。 |

---

## 8. 相关文档

| 文档 | 说明 |
|------|------|
| [README.md](../../README.md) | 项目总览与完整快速开始 |
| [环境变量](./env-vars.md) | `.env` 逐项说明 |
| [第三方模型](./third-party-models.md) | LiteLLM / 多厂商路由 |
| [常见问题](./faq.md) | 报错与协议相关 FAQ |

