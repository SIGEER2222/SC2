#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OCR 分析截图，提取文本信息用于判断游戏内状态。"""
import sys
import os

try:
    from PIL import Image
    import pytesseract
except ImportError as e:
    print(f"ERROR: missing dependency: {e}")
    sys.exit(1)

def analyze(path):
    if not os.path.exists(path):
        print(f"ERROR: file not found: {path}")
        return

    img = Image.open(path)
    print(f"Image size: {img.size}, mode: {img.mode}")

    # OCR with both English and Chinese
    print("\n=== OCR (eng+chi_sim) ===")
    try:
        text = pytesseract.image_to_string(img, lang='eng+chi_sim')
        print(text)
    except Exception as e:
        print(f"OCR with chi_sim failed: {e}")
        print("\n=== OCR (eng only) ===")
        text = pytesseract.image_to_string(img, lang='eng')
        print(text)

    # Also try to get data with confidence scores
    print("\n=== OCR data (eng, confidence > 50) ===")
    try:
        data = pytesseract.image_to_data(img, lang='eng', output_type=pytesseract.Output.DICT)
        for i in range(len(data['text'])):
            conf = int(data['conf'][i])
            txt = data['text'][i].strip()
            if conf > 50 and txt:
                print(f"  [{conf:3d}] '{txt}' at ({data['left'][i]},{data['top'][i]}) {data['width'][i]}x{data['height'][i]}")
    except Exception as e:
        print(f"OCR data failed: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Default to latest screenshot
        path = r"C:\Users\22448\AppData\Local\Temp\codex-shot-2026-07-11_14-24-23.png"
    else:
        path = sys.argv[1]
    analyze(path)
