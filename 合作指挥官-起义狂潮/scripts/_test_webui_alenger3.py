"""测试 webui /api/bootstrap 是否返回 Alenger3"""
import urllib.request
import json

url = "http://127.0.0.1:17761/api/bootstrap"
print(f"访问: {url}")
with urllib.request.urlopen(url) as resp:
    data = json.loads(resp.read().decode("utf-8"))

commanders = data.get("commanders", [])
print(f"总指挥官数: {len(commanders)}")
print()

alenger3 = [c for c in commanders if "Alenger" in c.get("runtime", "")]
if alenger3:
    print("=== 找到 Alenger3 ===")
    print(json.dumps(alenger3, ensure_ascii=False, indent=2))
else:
    print("=== 未找到 Alenger3 ===")

print()
print("所有指挥官 runtime 列表:")
for c in commanders:
    print(f"  - {c.get('runtime')}: {c.get('displayName')}")
