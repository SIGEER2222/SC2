#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
?????????????????
??????????????????????? Mod
"""

import os
import sys
import shutil
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("??¡Â???: python generate_adapter.py <????????>")
        print("???: python generate_adapter.py TerranRaynor")
        return
    
    commander_name = sys.argv[1]
    project_root = Path(__file__).parent.parent.parent
    adapters_dir = project_root / "Mods" / "AIRO" / "Adapters"
    template_dir = adapters_dir / "ZergKerriganAdapter.SC2Mod"
    
    new_adapter_name = f"{commander_name}Adapter"
    new_adapter_dir = adapters_dir / f"{new_adapter_name}.SC2Mod"
    
    if new_adapter_dir.exists():
        print(f"????: {new_adapter_name} ?????")
        return
    
    # ???????
    print(f"??????? {new_adapter_name}...")
    shutil.copytree(template_dir, new_adapter_dir)
    
    # ??????????
    for root, dirs, files in os.walk(new_adapter_dir):
        for file_name in files:
            file_path = Path(root) / file_name
            
            if file_name.startswith("LibAIROAdapter_ZergKerrigan"):
                new_file_name = file_name.replace("ZergKerrigan", commander_name)
                new_file_path = Path(root) / new_file_name
                shutil.move(file_path, new_file_path)
                file_path = new_file_path
            
            if file_path.suffix in [".galaxy", ".json"]:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                new_content = content.replace("ZergKerrigan", commander_name)
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
    
    print(f"??????? {new_adapter_name}??")
    print(f"¦Ë??: {new_adapter_dir}")
    print("\n?????:")
    print(f"1. ?? {new_adapter_dir}/Base.SC2Data/LibAIROAdapter_{commander_name}.galaxy")
    print(f"2. ?????????¦Ë??????")
    print(f"3. ???????????????????????")

if __name__ == "__main__":
    main()
