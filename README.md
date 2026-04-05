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

4) 运行容器（`.env` 和 `litellm_config.yaml` 必须外部挂载，`OPENAI_API_KEY` 运行时注入）：

```bash
docker run --rm -it \
  --name devi \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -p 4000:4000 \
  devi-offline:1.0
```

**仅跑 LiteLLM 代理（不启动容器内 CLI）**：默认入口会先起 LiteLLM 再起 `bun` 交互界面；若 bun 立刻退出，容器会一起结束，`docker logs` 可能几乎无输出。只要代理时可设：

```bash
docker run --rm --name devi \
  -e DEVI_PROXY_ONLY=1 \
  -e OPENAI_API_KEY="sk-xxxx" \
  -v "$PWD/.env:/app/.env:ro" \
  -v "$PWD/litellm_config.yaml:/app/litellm_config.yaml:ro" \
  -p 4000:4000 \
  devi-offline:1.0
```

5) Windows Git Bash 挂载路径异常时，可加：

```bash
MSYS_NO_PATHCONV=1 docker run ...
```

6) `.env` 中请确保：

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
