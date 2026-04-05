# Devi (Dev-cli)

基于 Claude Code 泄露源码修复的**本地可运行版本**，支持接入任意 Anthropic 兼容 API（如 MiniMax、OpenRouter 等）。

> 原始泄露源码无法直接运行。本仓库修复了启动链路中的多个阻塞问题，使完整的 Ink TUI 交互界面可以在本地工作。

<p align="center">
  <a href="#功能">功能</a> · <a href="#架构概览">架构概览</a> · <a href="#快速开始">快速开始</a> · <a href="docs/guide/env-vars.md">环境变量</a> · <a href="docs/guide/faq.md">FAQ</a> · <a href="docs/guide/global-usage.md">全局使用</a> · <a href="docs/site/index.html">首页预览</a> · <a href="#更多文档">更多文档</a>
</p>

---

## 功能

- 完整的 Ink TUI 交互界面（与官方 Claude Code 一致）
- `--print` 无头模式（脚本/CI 场景）
- 支持 MCP 服务器、插件、Skills
- 支持自定义 API 端点和模型（[第三方模型使用指南](docs/guide/third-party-models.md)）
- **Computer Use 桌面控制** — [使用指南](docs/features/computer-use.md)
- **记忆系统**（跨会话持久化记忆）— [使用指南](docs/memory/01-usage-guide.md)
- **多 Agent 系统**（多代理编排、并行任务、Teams 协作）— [使用指南](docs/agent/01-usage-guide.md) | [实现原理](docs/agent/02-implementation.md)
- **Skills 系统**（可扩展能力插件、自定义工作流）— [使用指南](docs/skills/01-usage-guide.md) | [实现原理](docs/skills/02-implementation.md)
- 降级 Recovery CLI 模式（`CLAUDE_CODE_FORCE_RECOVERY_CLI=1 ./bin/claude-haha`）

---

## 架构概览

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/images/01-overall-architecture.png" alt="整体架构"><br><b>整体架构</b></td>
    <td align="center" width="25%"><img src="docs/images/02-request-lifecycle.png" alt="请求生命周期"><br><b>请求生命周期</b></td>
    <td align="center" width="25%"><img src="docs/images/03-tool-system.png" alt="工具系统"><br><b>工具系统</b></td>
    <td align="center" width="25%"><img src="docs/images/04-multi-agent.png" alt="多 Agent 架构"><br><b>多 Agent 架构</b></td>
  </tr>
  <tr>
    <td align="center" width="25%"><img src="docs/images/05-terminal-ui.png" alt="终端 UI"><br><b>终端 UI</b></td>
    <td align="center" width="25%"><img src="docs/images/06-permission-security.png" alt="权限与安全"><br><b>权限与安全</b></td>
    <td align="center" width="25%"><img src="docs/images/07-services-layer.png" alt="服务层"><br><b>服务层</b></td>
    <td align="center" width="25%"><img src="docs/images/08-state-data-flow.png" alt="状态与数据流"><br><b>状态与数据流</b></td>
  </tr>
</table>

---

## 快速开始

### 1. 离线环境 Docker 部署（单容器启动 LiteLLM + CLI）

> 适用于：可在外网构建镜像，但目标运行环境完全离线。
>
> 前置要求：交互 CLI 依赖 Bun；Bun 在 Linux 上要求宿主机内核 **>= 5.1**，建议 **>= 5.6**。Docker 共享宿主机内核，因此若目标机器仍是 CentOS 7 / `3.10.x` 内核，通常只能稳定运行 LiteLLM，CLI 会出现“直接退出”或脚本无法执行的问题。详见 Bun 官方安装说明：https://bun.com/docs/installation

1) 外网构建并导出镜像：

```bash
docker build -t devi-offline:1.0 .
docker save -o devi-offline-1.0.tar devi-offline:1.0
```

2) 将 `devi-offline-1.0.tar` 拷贝到内网/离线环境并导入：

```bash
docker load -i devi-offline-1.0.tar
```

3) 先复制模板生成本地配置文件：

```bash
cp .env.example .env
cp litellm_config.example.yaml litellm_config.yaml
```

4) 运行容器（`.env` 和 `litellm_config.yaml` 必须外部挂载，`OPENAI_API_KEY` 按 `litellm_config.yaml` 里路由注入，如 `OPENAI_API_KEY`、`DASHSCOPE_API_KEY` 等）：

**单容器：LiteLLM + 交互 CLI（同一终端）**

```bash
docker run --rm -it \
  --name devi \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -p 4000:4000 \
  devi-offline:1.0
```

**仅 LiteLLM 代理（只占 4000，无 bun CLI）**

```bash
docker run --rm --name devi-litellm \
  -e DEVI_PROXY_ONLY=1 \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -p 4000:4000 \
  devi-offline:1.0
```

5) **双容器：一个跑 LiteLLM，一个跑交互 CLI + 挂载你的代码目录**

在同一台 Docker 主机上建网络，代理容器固定名字，CLI 容器通过 **容器名** 访问 `4000`（无需再映射 CLI 的端口）。

```bash
# 0. 准备配置（若尚未生成）
cp .env.example .env
cp litellm_config.example.yaml litellm_config.yaml
# 编辑 .env / litellm_config.yaml，保证模型名与下文 -e ANTHROPIC_MODEL 一致

# 1. 用户自定义网络
docker network create devi-net 2>/dev/null || true

# 2. 终端 A：启动 LiteLLM（后台常驻，宿主机 4000 可访问）
docker run -d --name devi-litellm --network devi-net \
  -e DEVI_PROXY_ONLY=1 \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -p 4000:4000 \
  --restart unless-stopped \
  devi-offline:1.0

# 3. 可选：健康检查
curl -sS http://127.0.0.1:4000/health/liveliness || curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4000/

# 4. 终端 B：只启动 CLI，挂载你的项目目录；API 指向同一网络内的代理
#    必须 --network devi-net，且用容器名 devi-litellm（不要用 localhost，那是 CLI 容器自己）
#    ANTHROPIC_MODEL 与 litellm_config.yaml 里 model_name 一致
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
  devi-offline:1.0

# 5. 用完后停止代理（CLI 容器退出后 --rm 已删除）
docker stop devi-litellm && docker rm devi-litellm
```

说明：`docker run -e ANTHROPIC_BASE_URL=...` 会覆盖 `.env` 里同名的 `localhost` 配置，使 CLI 走 `http://devi-litellm:4000`。若你改用其它模型名，请同步修改各 `ANTHROPIC_*_MODEL` 与 `litellm_config.yaml`。

**交互 CLI 秒退时排查：**

- **先看宿主机内核**：CLI 运行时是 Bun，Linux 宿主机内核需 **>= 5.1**，建议 **>= 5.6**。例如 CentOS 7 默认 `3.10.x` 内核即使 `docker run -it`、网络、`.env` 全部正确，CLI 也可能直接退出；这种情况需要升级宿主机内核或将 CLI 放到更新的 Linux 主机运行。LiteLLM 不受此限制。
- **不要用** `docker run ... | tee`：管道会让 `stdout` 不是 TTY，应用会走无头模式并很快退出，看起来像「秒退」。
- **Windows Git Bash / mintty**：即使用了 `-it`，也可能没有把真实 TTY 传进容器。若看到 `CLI mode requires an interactive TTY`，请改用 `winpty docker run -it ...`，或直接在 PowerShell / Windows Terminal 里运行同一条命令。
- **`preload.ts` 与 `CALLER_DIR`**：若 `.env` 里写了 `CALLER_DIR` 且指向宿主机路径，在容器里 `chdir` 会失败或跳到错误目录。双容器 CLI 建议在 `.env` 中**删除或注释 `CALLER_DIR`**，由入口脚本与 `bin/claude-haha` 自动设置。
- 入口在 `DEVI_CLI_ONLY=1` 时已改为 **`exec /app/bin/claude-haha`**（与本地 `./bin/claude-haha` 一致），请**重新构建镜像**后再试。
- **Windows 构建 Linux 镜像时行尾**：`docker/entrypoint.sh` 与 `bin/claude-haha` 必须是 LF。仓库已通过 `.gitattributes` 约束；若你在旧工作区构建过镜像，请重新 checkout / rebuild，避免 CRLF 被打进镜像。

6) Windows Git Bash 挂载路径异常时，可加：

```bash
MSYS_NO_PATHCONV=1 docker run ...
```

7) **单容器**（LiteLLM 与 CLI 同进程空间）时 `.env` 中请使用：

```env
ANTHROPIC_BASE_URL=http://localhost:4000
```


---

## 技术栈

| 类别 | 技术 |
|------|------|
| 运行时 | [Bun](https://bun.sh) |
| 语言 | TypeScript |
| 终端 UI | React + [Ink](https://github.com/vadimdemedes/ink) |
| CLI 解析 | Commander.js |
| API | Anthropic SDK |
| 协议 | MCP, LSP |

---

## 更多文档

| 文档 | 说明 |
|------|------|
| [环境变量](docs/guide/env-vars.md) | 完整环境变量参考和配置方式 |
| [第三方模型](docs/guide/third-party-models.md) | 接入 OpenAI / DeepSeek / Ollama 等非 Anthropic 模型 |
| [Computer Use](docs/features/computer-use.md) | 桌面控制功能（截屏、鼠标、键盘） |
| [记忆系统](docs/memory/01-usage-guide.md) | 跨会话持久化记忆的使用与实现 |
| [多 Agent 系统](docs/agent/01-usage-guide.md) | 多代理编排、并行任务执行与 Teams 协作 |
| [Skills 系统](docs/skills/01-usage-guide.md) | 可扩展能力插件、自定义工作流与条件激活 |
| [全局使用](docs/guide/global-usage.md) | 在任意目录启动 claude-haha |
| [常见问题](docs/guide/faq.md) | 常见错误排查 |
| [源码修复记录](docs/reference/fixes.md) | 相对于原始泄露源码的修复内容 |
| [项目结构](docs/reference/project-structure.md) | 代码目录结构说明 |

---

## Disclaimer

本仓库基于 2026-03-31 从 Anthropic npm registry 泄露的 Claude Code 源码。所有原始源码版权归 [Anthropic](https://www.anthropic.com) 所有。仅供学习和研究用途。
