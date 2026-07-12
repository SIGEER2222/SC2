"""
End-to-end test for Tab D "AI 起义狂潮" of web-launcher.
Assumes server is already running on http://localhost:17761/.
"""
import sys
from playwright.sync_api import sync_playwright

PORT = 17761
URL = f"http://localhost:{PORT}/"
SCREENSHOT_PATH = r"e:\Code\MyMod\SC2\合作指挥官-起义狂潮\web-launcher\test-screenshot-airo.png"

EXPECTED_MAP_IDS = {
    "traynor01", "traynor02", "traynor03",
    "thanson01", "thanson02",
    "ttosh01", "ttosh02",
    "ttychus01",
}

results = []


def record(step, ok, detail=""):
    results.append((step, ok, detail))
    status = "PASS" if ok else "FAIL"
    line = f"[{status}] {step}"
    if detail:
        line += f" - {detail}"
    print(line, flush=True)


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        # a. Open page
        try:
            page.goto(URL, wait_until="domcontentloaded")
            page.wait_for_load_state("networkidle", timeout=15000)
            record("a. 打开 http://localhost:17761/", True)
        except Exception as e:
            record("a. 打开 http://localhost:17761/", False, str(e))
            browser.close()
            return 1

        # b. Confirm 4 tabs
        try:
            tabs = page.locator(".tab").all()
            tab_count = len(tabs)
            tab_texts = [t.text_content().strip() for t in tabs]
            record("b. 页面有 4 个 tab", tab_count == 4,
                   f"actual={tab_count} texts={tab_texts}")
        except Exception as e:
            record("b. 页面有 4 个 tab", False, str(e))
            browser.close()
            return 1

        # c. Click tab D "AI 起义狂潮"
        try:
            tab_d = page.locator('.tab[data-tab="D"]')
            tab_d_text = tab_d.text_content().strip()
            tab_d.click()
            # Verify tab D content is visible
            page.wait_for_selector(
                '.tab-content[data-tab-content="D"]:not([hidden])',
                timeout=5000,
            )
            record('c. 点击 "AI 起义狂潮" tab (tab D)', True,
                   f"text={tab_d_text!r}")
        except Exception as e:
            record('c. 点击 "AI 起义狂潮" tab (tab D)', False, str(e))
            browser.close()
            return 1

        # Wait for AIRO data to load - airoStatus should contain "已加载"
        try:
            page.wait_for_function(
                "() => { const el = document.getElementById('airoStatus'); "
                "return el && el.textContent.includes('已加载'); }",
                timeout=15000,
            )
            airo_status = page.locator("#airoStatus").text_content().strip()
            record("   AIRO 数据加载完成", True, f"status={airo_status!r}")
        except Exception as e:
            airo_status = page.locator("#airoStatus").text_content().strip()
            record("   AIRO 数据加载完成", False,
                   f"status={airo_status!r} err={e}")

        # d. Verify commander selector - 19 commanders (1 original + 18 7vs1)
        try:
            commander_cards = page.locator(
                '#airoCommanderList .commander-card'
            ).all()
            commander_count = len(commander_cards)
            commander_count_badge = page.locator(
                "#airoCommanderCount"
            ).text_content().strip()

            # Check for original commander
            original_card = page.locator(
                '#airoCommanderList .commander-card', has_text="原版"
            )
            original_count = original_card.count()

            # Collect all commander runtimes (from <em> inside card)
            runtimes = []
            for card in commander_cards:
                ems = card.locator("em").all_text_contents()
                # The first em is the runtime
                if ems:
                    runtimes.append(ems[0].strip())

            has_original = "RevolutionOverdrive" in runtimes
            has_terran_raynor = "TerranRaynor" in runtimes
            expected_count = 19  # 1 original + 18 7vs1

            record(
                "d. 指挥官选择器包含 原版 (Revolution Overdrove)",
                has_original and original_count >= 1,
                f"original_count={original_count} has_runtime={has_original} "
                f"all_runtimes_count={len(runtimes)}",
            )
            record(
                "d. 指挥官选择器包含 18 个 7vs1 指挥官",
                commander_count == expected_count,
                f"actual_count={commander_count} badge={commander_count_badge} "
                f"has_terran_raynor={has_terran_raynor} runtimes={runtimes}",
            )
        except Exception as e:
            record("d. 指挥官选择器验证", False, str(e))

        # e. Verify map selector - 8 AIRO maps
        try:
            map_cards = page.locator('#airoMapList .map-card').all()
            map_count = len(map_cards)
            map_count_badge = page.locator("#airoMapCount").text_content().strip()

            # Collect map IDs (from <em> inside card)
            map_ids = []
            for card in map_cards:
                ems = card.locator("em").all_text_contents()
                if ems:
                    map_ids.append(ems[0].strip())

            missing = EXPECTED_MAP_IDS - set(map_ids)
            extra = set(map_ids) - EXPECTED_MAP_IDS
            record(
                "e. 地图选择器包含 8 个 AIRO 地图",
                map_count == 8 and not missing,
                f"actual_count={map_count} badge={map_count_badge} "
                f"missing={missing} extra={extra} ids={map_ids}",
            )
        except Exception as e:
            record("e. 地图选择器验证", False, str(e))

        # f. Select original commander, verify launch button enabled
        try:
            # Find original commander card by runtime em text
            original_card = page.locator(
                '#airoCommanderList .commander-card',
                has_text="RevolutionOverdrive",
            ).first
            original_card.click()
            page.wait_for_timeout(300)

            launch_btn = page.locator("#airoLaunchButton")
            is_disabled = launch_btn.is_disabled()
            summary_cmd = page.locator("#airoSummaryCommander").text_content().strip()
            record(
                'f. 选择 "原版" 指挥官后 launch 按钮可用',
                not is_disabled,
                f"is_disabled={is_disabled} summary_commander={summary_cmd!r}",
            )
        except Exception as e:
            record('f. 选择 "原版" 指挥官后 launch 按钮可用', False, str(e))

        # g. Select TerranRaynor commander, verify launch button enabled
        try:
            raynor_card = page.locator(
                '#airoCommanderList .commander-card',
                has_text="TerranRaynor",
            ).first
            raynor_card.click()
            page.wait_for_timeout(300)

            launch_btn = page.locator("#airoLaunchButton")
            is_disabled = launch_btn.is_disabled()
            summary_cmd = page.locator("#airoSummaryCommander").text_content().strip()
            record(
                'g. 选择 "TerranRaynor" 指挥官后 launch 按钮可用',
                not is_disabled,
                f"is_disabled={is_disabled} summary_commander={summary_cmd!r}",
            )
        except Exception as e:
            record('g. 选择 "TerranRaynor" 指挥官后 launch 按钮可用', False, str(e))

        # h. Do NOT click launch button (verified by not performing action)
        record("h. 不点击 launch 按钮（避免启动游戏）", True)

        # 4. Screenshot
        try:
            page.screenshot(path=SCREENSHOT_PATH, full_page=True)
            record("4. 截图保存", True, f"path={SCREENSHOT_PATH}")
        except Exception as e:
            record("4. 截图保存", False, str(e))

        browser.close()

    # Summary
    print("\n=== 测试汇总 ===", flush=True)
    passed = sum(1 for _, ok, _ in results if ok)
    failed = sum(1 for _, ok, _ in results if not ok)
    print(f"通过: {passed}  失败: {failed}", flush=True)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
