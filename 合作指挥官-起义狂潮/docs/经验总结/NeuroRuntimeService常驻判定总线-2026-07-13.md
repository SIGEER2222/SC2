# Neuro Runtime Service 常驻判定总线

时间：2026-07-13

## 目标

把 Neuro/Gary 接入从单次 launcher 内部启动，收敛为后续地图和 mod 开发共用的常驻服务。后续脚本优先通过服务 API 获取地图事件和完成度 verdict，避免各脚本重复读取 Bank、GameLogs、Alerts 并各自实现判定。

## 当前入口

- 启动/复用服务：`scripts/runtime-probe/start-neuro-runtime-service.ps1`
- 查询服务：`scripts/runtime-probe/query-neuro-runtime.ps1`
- Web/API 服务：`scripts/runtime-probe/web_server.py`（默认 `http://127.0.0.1:18080`，避免和 Neuro API WebUI 的 `8080` 冲突）
- 7vs1 启动器：`scripts/launch-7vs1-coop-test.ps1 -EnableNeuro -UseGary`

## 单实例规则

`start-neuro-runtime-service.ps1 -UseGary` 会先检查 `127.0.0.1:8000` 是否已有监听；已有监听时直接复用。若端口未监听但已有 `gary.exe` 进程，会等待该进程开放端口，不再启动第二个 Gary。只有没有监听、没有现有 Gary 进程且 `GaryPath` 存在时才启动 Gary。

## 判定 API

- `GET http://127.0.0.1:18080/api/verdict`：脚本友好的 pass/fail/pending 判定。
- `GET http://127.0.0.1:18080/api/events`：RuntimeProbe 与 NeuroIntegration Bank 归一化后的事件流。
- `GET http://127.0.0.1:18080/api/status`：健康状态、verdict 和事件计数。
- `GET http://127.0.0.1:18080/api/state`：完整 VerificationReport 兼容输出。

`wait-for-game-ready.ps1` 现在优先读取 `/api/verdict`，并要求 verdict 的 `last_update` 不早于本次等待开始时间，避免拿到上一次测试的旧结果。服务不可用或数据不新鲜时，才回退到旧的 GameLogs/Alerts 检查。

## 边界

底层服务仍然读取 `RuntimeProbe.SC2Bank`、`NeuroIntegration.SC2Bank` 等运行时事实源；迁移目标不是彻底禁止底层读文件，而是把读文件集中到服务层。新 launcher、批量验证、完成度判断脚本应调用服务 API，不应再各自解析 Bank 或 GameLogs。
