"""用 Playwright 下载 Template Maps（v3）。

策略：
1. 打开浏览器，导航到 sc2mods.com 详情页
2. 对每个文件，导航到下载 URL
3. 如果遇到 Cloudflare interactive 挑战，自动点击 turnstile checkbox
4. 等待下载触发并保存
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

def wait_for_cloudflare(page, timeout=120):
    """等待 Cloudflare 挑战通过，尝试自动点击 turnstile checkbox。"""
    for i in range(timeout):
        time.sleep(1)
        title = page.title()
        if "Just a moment" not in title and "Checking" not in title and "Attention Required" not in title:
            return True, i+1
        # 尝试点击 Cloudflare turnstile checkbox
        try:
            frames = page.frames
            for frame in frames:
                if "challenges.cloudflare.com" in (frame.url or ""):
                    try:
                        checkbox = frame.query_selector("input[type='checkbox']")
                        if checkbox:
                            checkbox.click(timeout=2000)
                    except:
                        pass
                    try:
                        body = frame.query_selector("body")
                        if body:
                            body.click(timeout=2000)
                    except:
                        pass
        except:
            pass
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
                "--disable-features=IsolateOrigins,site-per-process",
            ],
        )
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800},
            locale="en-US",
            accept_downloads=True,
        )
        page = context.new_page()

        # 步骤1：访问 sc2mods.com 详情页
        print("步骤1: 访问 sc2mods.com 详情页...", flush=True)
        page.goto("https://sc2mods.com/template-maps", timeout=60000, wait_until="domcontentloaded")
        ok, secs = wait_for_cloudflare(page, 30)
        if ok:
            print(f"  sc2mods.com Cloudflare 通过（{secs}s），标题: {page.title()}", flush=True)
        else:
            print(f"  sc2mods.com 仍在挑战页", flush=True)
        time.sleep(3)

        # 步骤2：预访问 curseforge.com 通过该域 Cloudflare
        print("\n步骤2: 预访问 curseforge.com...", flush=True)
        try:
            page.goto("https://www.curseforge.com/starcraft2", timeout=60000, wait_until="domcontentloaded")
            ok, secs = wait_for_cloudflare(page, 120)
            if ok:
                print(f"  curseforge.com Cloudflare 通过（{secs}s），标题: {page.title()}", flush=True)
            else:
                print(f"  curseforge.com 仍在挑战页，标题: {page.title()}", flush=True)
                print("  请在浏览器中手动完成 Cloudflare 验证（如果需要）...", flush=True)
                ok, secs = wait_for_cloudflare(page, 60)
                if ok:
                    print(f"  手动验证通过（{secs}s）", flush=True)
        except Exception as e:
            print(f"  预访问 curseforge.com 失败: {e}", flush=True)
        time.sleep(3)

        # 步骤3：逐个下载文件
        for file_id in range(FILE_COUNT):
            name = KNOWN_NAMES.get(file_id, f"Unknown_{file_id}")
            url = f"https://sc2mods.com/download.php?addon_id={ADDON_ID}&file_id={file_id}"
            print(f"\n[{file_id+1}/{FILE_COUNT}] 下载: {name}", flush=True)

            try:
                # 用 expect_download + goto
                with page.expect_download(timeout=120000) as download_info:
                    page.goto(url, timeout=120000, wait_until="commit")
                    # 如果遇到 Cloudflare 挑战，尝试自动通过
                    time.sleep(2)
                    title = page.title()
                    if "Just a moment" in title or "Checking" in title:
                        print(f"  遇到 Cloudflare 挑战，尝试自动通过...", flush=True)
                        ok, secs = wait_for_cloudflare(page, 120)
                        if ok:
                            print(f"  Cloudflare 通过（{secs}s）", flush=True)
                        else:
                            print(f"  Cloudflare 未通过，请手动验证...", flush=True)
                            ok, secs = wait_for_cloudflare(page, 60)

                download = download_info.value
                suggested = download.suggested_filename
                if not suggested:
                    suggested = f"{safe_filename(name)}.SC2Map"

                dest_path = os.path.join(DEST_DIR, suggested)
                if os.path.exists(dest_path):
                    os.remove(dest_path)
                download.save_as(dest_path)
                size = os.path.getsize(dest_path)
                print(f"  成功: {suggested} ({size:,} bytes)", flush=True)
                results.append((file_id, name, True, f"OK {suggested} {size} bytes"))
                success_count += 1

            except Exception as e:
                err_msg = str(e)[:200]
                print(f"  失败: {err_msg}", flush=True)
                results.append((file_id, name, False, err_msg))
                # 回到 sc2mods.com
                try:
                    page.goto("https://sc2mods.com/template-maps", timeout=30000, wait_until="domcontentloaded")
                    time.sleep(2)
                except:
                    pass

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
