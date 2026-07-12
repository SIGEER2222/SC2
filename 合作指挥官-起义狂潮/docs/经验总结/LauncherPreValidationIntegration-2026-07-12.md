# Launcher 启动前校验集成

## 变更摘要

2026-07-12，把 Galaxy 校验集成到 web launcher 的启动流程中：

- 新增 `web-launcher/lib/validation.mjs` 共享校验模块
- 更新所有 launch 路由（7vs1、reborn、airo、neuro、cmre），在启动前自动运行校验
- 新增 `web-launcher/config.example.json` 配置示例
- 默认启用启动前校验

## 使用方式

### 配置

创建 `web-launcher/config.json`，可以调整是否启用启动前校验：

```json
{
  "enablePreLaunchValidation": true
}
```

### 行为

- 当 `enablePreLaunchValidation: true`（默认）时，所有 launch 端点会在启动前运行 `node cli.mjs check --changed --run`
- 如果校验失败，直接返回 400 错误，不启动游戏
- 如果校验通过，继续正常启动游戏
