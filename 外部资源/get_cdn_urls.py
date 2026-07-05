"""用 Playwright 获取 Template Maps 所有文件的 CDN 下载 URL。

策略：
1. 打开 sc2mods.com 详情页（通过 Cloudflare）
2. 用 JavaScript fetch 获取每个 download.php 的重定向目标
   - fetch 同域 URL 不会触发 CORS
   - 用 redirect: "follow" 跟随重定向到 CDN
   - CDN URL 格式: mediafilez.forgecdn.net/files/XXX/YYY/filename
3. 输出所有 CDN URL 到文件
4. 后续用 PowerShell/Python requests 直接从 CDN 下载（无 Cloudflare）
"""
import os
import sys
import time
import json
from playwright.sync_api import sync_playwright

DEST_DIR = r"E:\Code\MyMod\SC2\外部资源\TemplateMaps"
URL_FILE = os.path.join(DEST_DIR, "cdn_urls.json")
ADDON_ID = 1556
FILE_COUNT = 23

KNOWN_NAMES = {
    0: "Home Soil", 1: "Wasted Lands", 2: "Korhal Carnage", 3: "Temple of Adun",
    4: "Face Off", 5: "Symbiosis", 6: "Space Hub", 7: "River Temple",
    8: "New Folsom", 9: "Mining Operations", 10: "Mar Sara Wastelands",
    11: "Jungle Temple", 12: "Dueling Colonies", 13: "Battleground", 14: "Deepspace 10",
}

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
    print(f"目标: 获取 {FILE_COUNT} 个文件的 CDN URL", flush=True)
    print(f"输出: {URL_FILE}", flush=True)
    print("=" * 70, flush=True)

    results = []

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

        # 获取每个文件的 CDN URL
        for file_id in range(FILE_COUNT):
            name = KNOWN_NAMES.get(file_id, f"Unknown_{file_id}")
            download_url = f"https://sc2mods.com/download.php?addon_id={ADDON_ID}&file_id={file_id}"
            print(f"\n[{file_id+1}/{FILE_COUNT}] {name}", flush=True)
            print(f"  download.php URL: {download_url}", flush=True)

            try:
                # 用 JavaScript fetch 获取重定向后的 URL
                # fetch 同域 URL 不会触发 CORS
                # 用 redirect: "follow" 跟随重定向
                # 但 fetch 返回的是 Response 对象，我们需要 response.url 来获取最终 URL
                js_code = f"""
                async () => {{
                    try {{
                        const response = await fetch("{download_url}", {{
                            credentials: "include",
                            redirect: "follow"
                        }});
                        return {{
                            ok: true,
                            finalUrl: response.url,
                            status: response.status,
                            contentType: response.headers.get("content-type") || "",
                            contentDisposition: response.headers.get("content-disposition") || ""
                        }};
                    }} catch (e) {{
                        return {{ ok: false, error: String(e) }};
                    }}
                }}
                """
                result = page.evaluate(js_code)

                if result and result.get("ok"):
                    final_url = result.get("finalUrl", "")
                    print(f"  最终 URL: {final_url[:120]}", flush=True)

                    # 如果是 CDN URL（mediafilez.forgecdn.net），直接记录
                    if "forgecdn.net" in final_url or "cdn" in final_url:
                        results.append({
                            "file_id": file_id,
                            "name": name,
                            "download_url": download_url,
                            "cdn_url": final_url,
                            "content_disposition": result.get("contentDisposition", "")
                        })
                        print(f"  CDN URL 获取成功", flush=True)
                    else:
                        # 可能是 HTML 页面（Cloudflare 挑战页或下载页面）
                        print(f"  非 CDN URL，可能是挑战页", flush=True)
                        print(f"  Content-Type: {result.get('contentType', '')}", flush=True)
                        results.append({
                            "file_id": file_id,
                            "name": name,
                            "download_url": download_url,
                            "cdn_url": None,
                            "final_url": final_url,
                            "content_disposition": result.get("contentDisposition", "")
                        })
                else:
                    err = result.get("error", "unknown") if result else "no result"
                    print(f"  fetch 失败: {err}", flush=True)
                    results.append({
                        "file_id": file_id,
                        "name": name,
                        "download_url": download_url,
                        "cdn_url": None,
                        "error": err
                    })

            except Exception as e:
                print(f"  异常: {e}", flush=True)
                results.append({
                    "file_id": file_id,
                    "name": name,
                    "download_url": download_url,
                    "cdn_url": None,
                    "error": str(e)
                })

            time.sleep(1)

        browser.close()

    # 保存结果
    with open(URL_FILE, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 70, flush=True)
    cdn_count = sum(1 for r in results if r.get("cdn_url"))
    print(f"获取完成: {cdn_count}/{FILE_COUNT} 个 CDN URL", flush=True)
    print(f"结果已保存到: {URL_FILE}", flush=True)

    # 打印所有 CDN URL
    print("\nCDN URLs:", flush=True)
    for r in results:
        if r.get("cdn_url"):
            print(f"  [{r['file_id']}] {r['name']}: {r['cdn_url']}", flush=True)
        else:
            print(f"  [{r['file_id']}] {r['name']}: FAILED", flush=True)

    return 0 if cdn_count > 0 else 1

if __name__ == "__main__":
    sys.exit(main())
