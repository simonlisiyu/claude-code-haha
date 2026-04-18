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

### 1. 离线环境 Docker 部署（LiteLLM 后台 + `docker exec` 启动 CLI）

> 适用于：可在外网构建镜像，但目标运行环境完全离线。
>
> 前置要求：交互 CLI 依赖 Bun；Bun 在 Linux 上要求宿主机内核 **>= 5.1**，建议 **>= 5.6**。Docker 共享宿主机内核，因此若目标机器仍是 CentOS 7 / `3.10.x` 内核，通常只能稳定运行 LiteLLM，CLI 会出现“直接退出”或脚本无法执行的问题。详见 Bun 官方安装说明：https://bun.com/docs/installation
>
> **仅持有镜像 tar、在内网导入部署**的逐步说明（含从镜像抽取配置模板、三种运行模式）：见 [docs/guide/docker-offline-deploy.md](docs/guide/docker-offline-deploy.md)。

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

4) 启动 LiteLLM 容器（`.env`、`litellm_config.yaml` 必须挂载；`OPENAI_API_KEY` 等按 `litellm_config.yaml` 里 `os.environ/...` 用 `-e` 注入）。

在同一台主机上创建网络并以后台方式启动（**只跑 LiteLLM**，宿主机 `4000` 可访问）。可选把业务代码挂到容器内 `/workspace`：

```bash
docker network create devi-net 2>/dev/null || true

docker run -d --name devi-litellm --network devi-net \
  -e DEVI_PROXY_ONLY=1 \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -v "/path/to/your/project:/workspace:rw" \
  -p 4000:4000 \
  --restart unless-stopped \
  devi-offline:1.0
```

不需要单独挂代码目录时，可去掉 `-v "/path/to/your/project:/workspace:rw"` 这一行。

可选健康检查：

```bash
curl -sS http://127.0.0.1:4000/health/liveliness
```

**进入同一容器启动交互 CLI**（LiteLLM 已在容器内监听 `4000`，`.env` 里 `ANTHROPIC_BASE_URL` 请使用 **`http://127.0.0.1:4000`**）：

```bash
docker exec -it devi-litellm bash
cd /app
bun --env-file=.env ./src/entrypoints/cli.tsx
```

若 CLI 要在挂载的业务目录下工作，进入容器后：

```bash
cd /workspace
bun --env-file=/app/.env /app/src/entrypoints/cli.tsx
```

（使用绝对路径指向镜像内入口，避免相对路径 `./src` 找不到。）

用完后停止并删除容器：

```bash
docker stop devi-litellm && docker rm devi-litellm
```

**交互 CLI 秒退时排查：**

- **先看宿主机内核**：CLI 依赖 Bun，Linux 宿主机内核建议 **>= 5.6**（最低 **>= 5.1**）。过旧内核上 LiteLLM 仍可跑，CLI 可能直接退出。
- **`docker exec` 必须带 `-t`**：需要交互 TTY 时使用 `docker exec -it`，否则 Ink 界面可能秒退。
- **不要用** `docker exec ... | tee`：管道会导致 stdout 非 TTY，易走无头逻辑并快速退出。
- **Windows Git Bash / mintty**：若 TTY 异常，可改用 `winpty docker exec -it ...` 或在 PowerShell / Windows Terminal 中执行。
- **`preload.ts` 与 `CALLER_DIR`**：若 `.env` 含仅宿主机有效的 `CALLER_DIR`，在容器内会 `chdir` 失败；建议在用于 Docker 的 `.env` 中删除或注释 **`CALLER_DIR`**。
- **Windows 构建 Linux 镜像时行尾**：`docker/entrypoint.sh` 与 `bin/claude-haha` 须为 LF，见 `.gitattributes`。

5) Windows Git Bash 挂载路径异常时，可加：

```bash
MSYS_NO_PATHCONV=1 docker run ...
```

6) 与 LiteLLM 同容器跑 CLI 时，`.env` 中请使用：

```env
ANTHROPIC_BASE_URL=http://127.0.0.1:4000
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
| [内网 Docker 镜像部署](docs/guide/docker-offline-deploy.md) | 导入 tar、配置与单容器 / 双容器运行清单 |
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
