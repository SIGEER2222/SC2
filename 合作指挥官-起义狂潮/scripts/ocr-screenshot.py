#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""SC2 截图 OCR 识别工具（基于 Windows.Media.Ocr）"""
import asyncio
import sys
import winocr
from PIL import Image


async def ocr_image(image_path, lang='zh-Hans-CN'):
    img = Image.open(image_path)
    result = await winocr.recognize_pil(img, lang=lang)
    return result.text


def main():
    if len(sys.argv) < 2:
        print("Usage: python ocr-screenshot.py <image_path> [lang]")
        sys.exit(1)
    image_path = sys.argv[1]
    lang = sys.argv[2] if len(sys.argv) > 2 else 'zh-Hans-CN'
    text = asyncio.run(ocr_image(image_path, lang))
    print(text)


if __name__ == '__main__':
    main()
