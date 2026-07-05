"""用 Playwright 下载 Template Maps（v6）。

修复 v3 的问题：浏览器缓存了 download.php 的重定向响应，导致所有 file_id
都下载了同一个文件。

策略：
1. 打开 sc2mods.com 详情页（通过 Cloudflare）
2. 对每个文件，在 URL 后加随机参数避免缓存
3. 用 page.goto + expect_download 下载
4. 保持在同一个 context 中（Cloudflare cookies 有效）
"""
import os
import sys
import time
import random
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
    seen_urls = set()  # 记录已下载的 CDN URL，检测重复

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
            # 加随机参数避免缓存
            cache_buster = random.randint(100000, 999999)
            download_url = f"https://sc2mods.com/download.php?addon_id={ADDON_ID}&file_id={file_id}&_cb={cache_buster}"
            print(f"\n[{file_id+1}/{FILE_COUNT}] 下载: {name}", flush=True)
            print(f"  URL: {download_url}", flush=True)

            try:
                # 用 expect_download + goto
                # wait_until="commit" 表示等浏览器收到第一个字节就返回
                # 这样不会因为下载响应（没有页面）而超时
                with page.expect_download(timeout=120000) as download_info:
                    page.goto(download_url, timeout=120000, wait_until="commit")

                download = download_info.value
                actual_url = download.url
                suggested = download.suggested_filename
                print(f"  实际下载 URL: {actual_url[:120]}", flush=True)
                print(f"  建议文件名: {suggested}", flush=True)

                # 检测重复 URL
                if actual_url in seen_urls:
                    print(f"  警告: 此 URL 已下载过，可能是重复文件", flush=True)
                seen_urls.add(actual_url)

                if not suggested:
                    suggested = f"{safe_filename(name)}.SC2Map"

                # 用地图名作为文件名
                dest_filename = f"{safe_filename(name)}.SC2Map"
                # 如果 suggested 文件名包含有意义的名称，保留它
                if suggested and suggested != "download" and "." in suggested:
                    # 检查 suggested 是否已经是地图名
                    if safe_filename(name).lower() not in suggested.lower():
                        dest_filename = f"{safe_filename(name)}_{suggested}"
                    else:
                        dest_filename = suggested

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
                # 回到详情页
                try:
                    page.goto("https://sc2mods.com/template-maps", timeout=30000, wait_until="domcontentloaded")
                    wait_for_cloudflare(page, 30)
                    time.sleep(2)
                except:
                    pass

            time.sleep(3)

        browser.close()

    print("\n" + "=" * 70, flush=True)
    print(f"下载完成: {success_count}/{FILE_COUNT} 成功", flush=True)
    print(f"唯一 CDN URL 数: {len(seen_urls)}", flush=True)

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
