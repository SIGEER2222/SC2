"""用 Playwright 下载 Template Maps（v4）。

修复 v3 的问题：所有 file_id 都下载了同一个文件。
策略：每个文件用新的浏览器 context 避免缓存，并打印下载 URL 诊断。
"""
import os
import sys
import time
from playwright.sync_api import sync_playwright

DEST_DIR = r"E:\Code\MyMod\SC2\外部资源\TemplateMaps"
ADDON_ID = 1556
FILE_COUNT = 23

KNOWN_NAMES = {
    0: "Home Soil", 1: "Wasted Lands", 2: "Korhal Carnage", 3: "Temple of Adun",
    4: "Face Off", 5: "Symbiosis", 6: "Space Hub", 7: "River Temple",
    8: "New Folsom", 9: "Mining Operations", 10: "Mar Sara Wastelands",
    11: "Jungle Temple", 12: "Dueling Colonies", 13: "Battleground", 14: "Deepspace 10",
}

def safe_filename(name):
    keep = "-_.()abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
    return "".join(c for c in name if c in keep).strip().replace(" ", "_")

def wait_for_cloudflare(page, timeout=60):
    """等待 Cloudflare 挑战通过。"""
    for i in range(timeout):
        time.sleep(1)
        title = page.title()
        if "Just a moment" not in title and "Checking" not in title and "Attention Required" not in title:
            return True, i+1
    return False, timeout

def main():
    os.makedirs(DEST_DIR, exist_ok=True)
    sys.stdout.reconfigure(line_buffering=True)
    print(f"目标目录: {DEST_DIR}", flush=True)
    print(f"计划下载 {FILE_COUNT} 个文件", flush=True)
    print("=" * 70, flush=True)

    results = []
    success_count = 0

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
            ],
        )

        # 先用第一个 context 通过 sc2mods.com 和 curseforge.com 的 Cloudflare
        print("预步骤: 通过 Cloudflare 验证...", flush=True)
        init_context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800},
            locale="en-US",
            accept_downloads=True,
        )
        init_page = init_context.new_page()
        init_page.goto("https://sc2mods.com/template-maps", timeout=60000, wait_until="domcontentloaded")
        wait_for_cloudflare(init_page, 30)
        print(f"  sc2mods.com OK", flush=True)
        # 预访问 curseforge.com
        init_page.goto("https://www.curseforge.com/starcraft2", timeout=60000, wait_until="domcontentloaded")
        ok, secs = wait_for_cloudflare(init_page, 120)
        if ok:
            print(f"  curseforge.com OK（{secs}s）", flush=True)
        else:
            print(f"  curseforge.com 未通过，继续尝试...", flush=True)
        # 获取 cookies
        cookies = init_context.cookies()
        print(f"  获取 {len(cookies)} 个 cookies", flush=True)
        init_context.close()

        # 逐个下载文件，每个用新的 context 但共享 cookies
        for file_id in range(FILE_COUNT):
            name = KNOWN_NAMES.get(file_id, f"Unknown_{file_id}")
            url = f"https://sc2mods.com/download.php?addon_id={ADDON_ID}&file_id={file_id}"
            print(f"\n[{file_id+1}/{FILE_COUNT}] 下载: {name}", flush=True)
            print(f"  URL: {url}", flush=True)

            # 每个文件用新的 context（避免下载缓存），但添加之前的 cookies
            context = browser.new_context(
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                viewport={"width": 1280, "height": 800},
                locale="en-US",
                accept_downloads=True,
            )
            context.add_cookies(cookies)
            page = context.new_page()

            try:
                # 先导航到 sc2mods.com 主页通过 Cloudflare（新 context 需要）
                page.goto("https://sc2mods.com/", timeout=30000, wait_until="domcontentloaded")
                wait_for_cloudflare(page, 30)
                time.sleep(1)

                # 用 expect_download + goto 下载
                with page.expect_download(timeout=120000) as download_info:
                    page.goto(url, timeout=120000, wait_until="commit")
                    # 如果遇到 Cloudflare 挑战
                    time.sleep(2)
                    title = page.title()
                    if "Just a moment" in title or "Checking" in title:
                        print(f"  遇到 Cloudflare 挑战，等待通过...", flush=True)
                        ok, secs = wait_for_cloudflare(page, 120)
                        if ok:
                            print(f"  Cloudflare 通过（{secs}s）", flush=True)

                download = download_info.value
                # 打印下载 URL 诊断
                download_url = download.url
                suggested = download.suggested_filename
                print(f"  下载 URL: {download_url[:100]}...", flush=True)
                print(f"  建议文件名: {suggested}", flush=True)

                if not suggested:
                    suggested = f"{safe_filename(name)}.SC2Map"

                # 用地图名重命名，避免覆盖
                dest_filename = f"{safe_filename(name)}_{suggested}" if suggested != f"{safe_filename(name)}.SC2Map" else suggested
                # 如果文件名已经包含地图名，不重复添加
                if safe_filename(name).lower() in dest_filename.lower():
                    dest_filename = suggested
                else:
                    dest_filename = f"{safe_filename(name)}_{suggested}"

                dest_path = os.path.join(DEST_DIR, dest_filename)
                if os.path.exists(dest_path):
                    os.remove(dest_path)
                download.save_as(dest_path)
                size = os.path.getsize(dest_path)
                print(f"  成功: {dest_filename} ({size:,} bytes)", flush=True)
                results.append((file_id, name, True, f"OK {dest_filename} {size} bytes"))
                success_count += 1

            except Exception as e:
                err_msg = str(e)[:200]
                print(f"  失败: {err_msg}", flush=True)
                results.append((file_id, name, False, err_msg))

            context.close()
            time.sleep(2)

        browser.close()

    print("\n" + "=" * 70, flush=True)
    print(f"下载完成: {success_count}/{FILE_COUNT} 成功", flush=True)
    print("\n详细结果:", flush=True)
    for file_id, name, ok, msg in results:
        status = "OK" if ok else "FAIL"
        print(f"  [{status}] file_id={file_id} {name}: {msg}", flush=True)

    # 目录内容
    print("\n" + "=" * 70, flush=True)
    print(f"目录内容: {DEST_DIR}", flush=True)
    if os.path.exists(DEST_DIR):
        files = os.listdir(DEST_DIR)
        if files:
            total_size = 0
            for f in sorted(files):
                fp = os.path.join(DEST_DIR, f)
                if os.path.isfile(fp):
                    size = os.path.getsize(fp)
                    total_size += size
                    print(f"  {f} ({size:,} bytes)", flush=True)
            print(f"  总计: {len(files)} 个文件, {total_size:,} bytes", flush=True)
        else:
            print("  （空目录）", flush=True)

    return 0 if success_count > 0 else 1

if __name__ == "__main__":
    sys.exit(main())
