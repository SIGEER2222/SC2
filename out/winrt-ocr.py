# -*- coding: utf-8 -*-
"""使用 Windows 自带 OCR (Windows.Media.Ocr) 分析截图。"""
import os
import sys
import asyncio

async def analyze_image(path):
    if not os.path.exists(path):
        print(f"ERROR: file not found: {path}")
        return

    from winrt.windows.media.ocr import OcrEngine
    from winrt.windows.graphics.imaging import BitmapDecoder, SoftwareBitmap
    from winrt.windows.storage import StorageFile, FileAccessMode

    # 获取所有可用语言
    langs = OcrEngine.available_recognizer_languages
    print(f"Available OCR languages: {len(langs)}")
    for lang in langs:
        print(f"  - {lang.language_tag}")

    if len(langs) == 0:
        print("No OCR language available!")
        return

    # 优先选中文
    selected_lang = None
    for lang in langs:
        if lang.language_tag.startswith("zh"):
            selected_lang = lang
            break
    if selected_lang is None:
        selected_lang = langs[0]

    print(f"\nUsing language: {selected_lang.language_tag}")
    engine = OcrEngine.try_create_from_language(selected_lang)
    if engine is None:
        print("Failed to create OCR engine")
        return

    # 加载图片
    file_path = os.path.abspath(path)
    storage_file = await StorageFile.get_file_from_path_async(file_path)
    stream = await storage_file.open_async(FileAccessMode.READ)
    decoder = await BitmapDecoder.create_async(stream)
    bitmap = await decoder.get_software_bitmap_async()

    # OCR
    result = await engine.recognize_async(bitmap)
    text = result.text

    print("\n=== OCR Result ===")
    print(text)

    # 详细的行信息
    print("\n=== Lines ===")
    lines = result.lines
    for i in range(lines.size):
        line = lines.get_at(i)
        print(f"Line {i}: {line.text}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        path = r"C:\Users\22448\AppData\Local\Temp\codex-shot-2026-07-11_14-24-23.png"
    else:
        path = sys.argv[1]

    try:
        asyncio.run(analyze_image(path))
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
