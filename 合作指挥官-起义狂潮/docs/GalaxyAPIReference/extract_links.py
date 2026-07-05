"""
从 mapster.talv.space/galaxy/reference 主页 HTML 提取所有函数详情页链接。
用正则匹配 <li><strong><a href="...">Name</a></strong> — `type` — FuncName</li>
并按当前所属 h2/h3 主分类分组。
"""
import re
import json
from pathlib import Path

ROOT = Path(r"E:\Code\MyMod\SC2\合作指挥官-起义狂潮\docs\GalaxyAPIReference")
INDEX_HTML = ROOT / "raw" / "_index.html"
OUT_JSON = ROOT / "raw" / "_links.json"

BASE_URL = "https://mapster.talv.space"

# 匹配 h2 / h3 标题（带 id）
H2_RE = re.compile(r'<h2 id="([^"]+)"><a[^>]*>#</a>\s*(.*?)</h2>', re.IGNORECASE)
H3_RE = re.compile(r'<h3 id="([^"]+)"><a[^>]*>#</a>\s*(.*?)</h3>', re.IGNORECASE)
# 匹配列表项中的链接：<li><strong><a href="/galaxy/reference/xxx">Name</a></strong> — `type` — FuncName</li>
LI_RE = re.compile(
    r'<li><strong><a href="/galaxy/reference/([^"]+)">([^<]+)</a></strong>'
    r'\s*—\s*<code>([^<]*)</code>'
    r'\s*—\s*([^<]+?)</li>',
    re.IGNORECASE
)


def main():
    html = INDEX_HTML.read_text(encoding="utf-8", errors="replace")

    # 先按 h2/h3 切片：用正则找到所有 h2/h3 的位置
    headers = []  # [(pos, level, id, title)]
    for m in H2_RE.finditer(html):
        headers.append((m.start(), 2, m.group(1), m.group(2).strip()))
    for m in H3_RE.finditer(html):
        headers.append((m.start(), 3, m.group(1), m.group(2).strip()))
    headers.sort(key=lambda x: x[0])

    # 给每个 LI 找到它所属的最近 h2/h3
    entries = []
    seen_slugs = set()
    current_h2 = ""
    current_h3 = ""

    for m in LI_RE.finditer(html):
        pos = m.start()
        # 找到 pos 之前最后一个 h2 和 h3
        h2_at = ""
        h3_at = ""
        for hpos, level, hid, title in headers:
            if hpos > pos:
                break
            if level == 2:
                h2_at = title
                h3_at = ""  # 新 h2 重置 h3
            else:
                h3_at = title
        slug = m.group(1)
        if slug in seen_slugs:
            continue
        # 排除 preset-xxx（预设类型，不是函数）
        if slug.startswith("preset-"):
            continue
        seen_slugs.add(slug)
        entries.append({
            "slug": slug,
            "url": f"{BASE_URL}/galaxy/reference/{slug}",
            "gui_name": m.group(2).strip(),
            "return_type": m.group(3).strip(),
            "func_name": m.group(4).strip(),
            "h2": h2_at,
            "h3": h3_at,
        })

    print(f"共提取 {len(entries)} 个函数链接")
    h2_set = sorted({e["h2"] for e in entries if e["h2"]})
    print(f"主分类数: {len(h2_set)}")

    by_h2 = {}
    for e in entries:
        by_h2.setdefault(e["h2"], []).append(e)
    for h2, items in sorted(by_h2.items()):
        print(f"  {h2}: {len(items)} 个函数")

    OUT_JSON.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n清单已写入: {OUT_JSON}")


if __name__ == "__main__":
    main()
