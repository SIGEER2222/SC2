# 任务总结：Neuro Runtime Service 判定迁移

- 任务类型：SC2 runtime tooling / Neuro service integration
- 时间戳：2026-07-13 15:54:39 +08:00
- 任务内容：把 Neuro/Gary 接入改为常驻共享服务，避免重复启动 Gary；新增服务 verdict/events API，并把旧的运行时判定入口迁移为优先查询服务。
- 任务结果：新增 `start-neuro-runtime-service.ps1` 和 `query-neuro-runtime.ps1`；`web_server.py` 增加 `http://127.0.0.1:18080/api/verdict`、`/api/events`、`/api/status`；`launch-7vs1-coop-test.ps1` 改为调用共享服务；`wait-for-game-ready.ps1` 优先使用服务的新鲜 verdict，GameLogs/Alerts 作为兜底。
- 任务耗时：约 1 小时
- 任务备注：底层服务仍集中读取 RuntimeProbe/NeuroIntegration Bank；迁移目标是让其他脚本不再分散读取文件。真实 Gary E2E 需要保持 `-UseGary`，服务会复用 `127.0.0.1:8000` 上已有监听，避免启动多个 Gary。
