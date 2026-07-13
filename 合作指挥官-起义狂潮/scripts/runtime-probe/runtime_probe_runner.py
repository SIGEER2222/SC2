"""RuntimeProbe Runner - 主运行器

监听 RuntimeProbe.SC2Bank 文件变更，解析数据，生成诊断报告。

用法:
    python runtime_probe_runner.py --banks-path "C:\\Users\\22448\\Documents\\StarCraft II\\Banks" --composition-id "raynor-7vs1"

    python runtime_probe_runner.py --once  # 只读取一次并退出
"""

import argparse
import json
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from bank_io import parse_bank_file
from normalize_probe import build_verification_report, report_to_markdown

BANK_FILE_NAME = "RuntimeProbe.SC2Bank"
DEFAULT_OUTPUT_DIR = Path(__file__).parent / "reports"


class RuntimeProbeRunner:
    def __init__(
        self,
        banks_path: str,
        composition_id: str = "unknown",
        output_dir: Path | None = None,
        run_id: str | None = None,
        poll_interval: float = 0.5,
    ):
        self.banks_path = Path(banks_path)
        self.bank_file = self.banks_path / BANK_FILE_NAME
        self.composition_id = composition_id
        self.output_dir = output_dir or DEFAULT_OUTPUT_DIR
        self.run_id = run_id or f"run-{datetime.now().strftime('%Y%m%d')}-{datetime.now().strftime('%H%M%S')}"
        self.poll_interval = poll_interval

        self.last_mtime: float = 0.0
        self.last_report: dict[str, Any] | None = None

        self.output_dir.mkdir(parents=True, exist_ok=True)

    def run_once(self) -> dict[str, Any] | None:
        """读取一次 Bank 并生成报告。"""
        if not self.bank_file.exists():
            print(f"[WARN] Bank file not found: {self.bank_file}")
            return None

        mtime = self.bank_file.stat().st_mtime
        if mtime == self.last_mtime:
            return self.last_report

        self.last_mtime = mtime
        bank_data = parse_bank_file(self.bank_file)

        if not bank_data or "probe_state" not in bank_data:
            print("[WARN] Bank file has no probe_state section")
            return None

        report = build_verification_report(
            bank_data,
            composition_id=self.composition_id,
            run_id=self.run_id,
        )
        self.last_report = report
        self._save_report(report)
        self._print_summary(report)
        return report

    def run_watch(self, duration: float | None = None) -> None:
        """持续监听 Bank 文件变更。"""
        print(f"[RuntimeProbe] Watching: {self.bank_file}")
        print(f"[RuntimeProbe] Run ID: {self.run_id}")
        print(f"[RuntimeProbe] Composition: {self.composition_id}")
        print(f"[RuntimeProbe] Output: {self.output_dir}")
        print(f"[RuntimeProbe] Poll interval: {self.poll_interval}s")
        if duration:
            print(f"[RuntimeProbe] Duration: {duration}s")
        print()

        start_time = time.time()
        no_heartbeat_count = 0

        while True:
            if duration and (time.time() - start_time) > duration:
                print(f"\n[RuntimeProbe] Duration reached ({duration}s), exiting.")
                break

            report = self.run_once()

            if report is None:
                no_heartbeat_count += 1
                if no_heartbeat_count % 10 == 0:
                    print(f"[RuntimeProbe] Still waiting for Bank... ({no_heartbeat_count * self.poll_interval:.0f}s)")
            else:
                no_heartbeat_count = 0

            time.sleep(self.poll_interval)

    def _save_report(self, report: dict[str, Any]) -> None:
        """保存 JSON 和 Markdown 报告。"""
        json_path = self.output_dir / "latest-report.json"
        md_path = self.output_dir / "latest-report.md"

        json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
        md_path.write_text(report_to_markdown(report), encoding="utf-8")

        # 也保存带时间戳的副本
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        ts_json = self.output_dir / f"report-{ts}.json"
        ts_json.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    def _print_summary(self, report: dict[str, Any]) -> None:
        """打印简要摘要。"""
        state = report["probe_state"]
        status = report["status"]
        units = report["probe_units"]
        upgrades = report["probe_upgrades"]

        all_pass = all(status.values())
        icon = "OK" if all_pass else "FAIL"

        print(
            f"[{datetime.now().strftime('%H:%M:%S')}] "
            f"Phase={state.get('phase', '?')} "
            f"Units={len(units)} "
            f"Upgrades={len(upgrades)} "
            f"Min={state.get('minerals', 0)} "
            f"Gas={state.get('gas', 0)} "
            f"Supply={state.get('supply_used', 0)}/{state.get('supply_cap', 0)} "
            f"[{icon}]"
        )


def main():
    parser = argparse.ArgumentParser(description="RuntimeProbe Runner")
    parser.add_argument(
        "--banks-path",
        default=r"C:\Users\22448\Documents\StarCraft II\Banks",
        help="SC2 Banks 目录路径",
    )
    parser.add_argument("--composition-id", default="unknown", help="组合配置 ID")
    parser.add_argument("--run-id", default=None, help="运行 ID")
    parser.add_argument("--output-dir", default=None, help="报告输出目录")
    parser.add_argument("--once", action="store_true", help="只读取一次并退出")
    parser.add_argument("--duration", type=float, default=None, help="监听持续时间（秒）")
    parser.add_argument("--poll-interval", type=float, default=0.5, help="轮询间隔（秒）")
    args = parser.parse_args()

    output_dir = Path(args.output_dir) if args.output_dir else None

    runner = RuntimeProbeRunner(
        banks_path=args.banks_path,
        composition_id=args.composition_id,
        output_dir=output_dir,
        run_id=args.run_id,
        poll_interval=args.poll_interval,
    )

    if args.once:
        report = runner.run_once()
        if report:
            print(json.dumps(report, indent=2, ensure_ascii=False))
            sys.exit(0)
        else:
            sys.exit(1)
    else:
        runner.run_watch(duration=args.duration)


if __name__ == "__main__":
    main()
