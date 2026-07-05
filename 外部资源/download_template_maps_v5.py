"""用 Playwright 下载 Template Maps（v5）。

策略：
1. 打开 sc2mods.com 详情页（通过 Cloudflare）
2. 对每个文件，用 JavaScript 动态创建 <a> 标签并 click() 触发下载
3. 用 expect_download 捕获下载
4. 保持在同一个 context 中（Cloudflare cookies 有效）
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
            args=["--disable-blink-features=AutomationControlled", "--no-sandbox"],
        )
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800},
            locale="en-US",
            accept_downloads=True,
        )
        page = context.new_page()

        # 访问详情页
        print("访问 sc2mods.com 详情页...", flush=True)
        page.goto("https://sc2mods.com/template-maps", timeout=60000, wait_until="domcontentloaded")
        ok, secs = wait_for_cloudflare(page, 30)
        if ok:
            print(f"  Cloudflare 通过（{secs}s）", flush=True)
        else:
            print(f"  Cloudflare 未通过", flush=True)
        time.sleep(3)

        # 逐个下载文件
        for file_id in range(FILE_COUNT):
            name = KNOWN_NAMES.get(file_id, f"Unknown_{file_id}")
            download_url = f"https://sc2mods.com/download.php?addon_id={ADDON_ID}&file_id={file_id}"
            print(f"\n[{file_id+1}/{FILE_COUNT}] 下载: {name}", flush=True)
            print(f"  URL: {download_url}", flush=True)

            try:
                # 用 JavaScript 动态创建 <a> 标签并 click 触发下载
                # 这样浏览器会在当前页面触发下载，不会导航到新页面
                with page.expect_download(timeout=120000) as download_info:
                    js_click = f"""
                    () => {{
                        const a = document.createElement('a');
                        a.href = "{download_url}";
                        a.download = "";
                        a.style.display = 'none';
                        document.body.appendChild(a);
                        a.click();
                        document.body.removeChild(a);
                    }}
                    """
                    page.evaluate(js_click)

                download = download_info.value
                download_url_actual = download.url
                suggested = download.suggested_filename
                print(f"  下载 URL: {download_url_actual[:120]}", flush=True)
                print(f"  建议文件名: {suggested}", flush=True)

                if not suggested:
                    suggested = f"{safe_filename(name)}.SC2Map"

                # 用地图名作为文件名，避免冲突
                dest_filename = f"{safe_filename(name)}.SC2Map"
                # 如果 suggested 文件名有扩展名且不是 .SC2Map，用 suggested
                if suggested and "." in suggested and not suggested.endswith(".SC2Map"):
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

            time.sleep(3)  # 间隔避免触发限流

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
