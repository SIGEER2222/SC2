#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AIRO Map Event Analysis Tool
Analyzes player-related events in all AIRO maps
"""

import os
import re
import json
from pathlib import Path
from collections import defaultdict, OrderedDict

PROJECT_ROOT = Path(__file__).parent.parent.parent
AIRO_MAPS_DIR = PROJECT_ROOT / "Maps" / "AIRO"
OUTPUT_DIR = PROJECT_ROOT / "docs" / "superpowers" / "map_analysis"


def find_create_unit_calls(galaxy_script: str) -> list:
    """
    Analyze unit creation calls in MapScript.galaxy
    Returns unit types, positions, trigger conditions, etc.
    """
    results = []
    
    # Search for common unit creation functions
    patterns = [
        # libNtve_gf_CreateUnitsWithDefaultFacing
        (r'libNtve_gf_CreateUnitsWithDefaultFacing\s*\(\s*([^,]+)\s*,\s*"([^"]+)"\s*,\s*[^,]+,\s*([^,]+)\s*,\s*([^)]+)\)', 
         'CreateUnitsWithDefaultFacing'),
        
        # UnitCreate
        (r'UnitCreate\s*\(\s*"([^"]+)"\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)',
         'UnitCreate'),
         
        # RescueUnit
        (r'libNtve_gf_RescueUnit\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*[^)]+\)',
         'RescueUnit'),
    ]
    
    # Scan line by line
    lines = galaxy_script.split('\n')
    for i, line in enumerate(lines, 1):
        for pattern, call_type in patterns:
            matches = re.findall(pattern, line)
            if matches:
                results.append({
                    'line': i,
                    'type': call_type,
                    'match': matches,
                    'context': line.strip()
                })
    
    # Find trigger definitions
    trigger_pattern = r'(gt_\w+)\s*=\s*TriggerCreate\s*\(\s*"([^"]+)"\s*\)'
    triggers = re.findall(trigger_pattern, galaxy_script)
    
    return results, triggers


def analyze_map(map_dir: Path) -> dict:
    """Analyze a single map"""
    map_name = map_dir.name
    map_script = map_dir / "MapScript.galaxy"
    
    if not map_script.exists():
        return {'map': map_name, 'error': 'No MapScript.galaxy found'}
    
    with open(map_script, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Analysis
    create_calls, triggers = find_create_unit_calls(content)
    
    # Search for common game event keywords
    keywords = {
        'Drop': ['drop', 'Drop'],
        'Rescue': ['rescue', 'Rescue'],
        'Bonus': ['bonus', 'Bonus'],
        'Mission': ['mission', 'objective'],
    }
    
    found_keywords = defaultdict(list)
    for keyword_category, keyword_list in keywords.items():
        for keyword in keyword_list:
            for line_num, line in enumerate(content.split('\n'), 1):
                if keyword in line:
                    found_keywords[keyword_category].append({
                        'line': line_num,
                        'text': line.strip()
                    })
    
    return {
        'map': map_name,
        'create_calls': create_calls,
        'triggers': triggers,
        'keywords': dict(found_keywords),
    }


def generate_report(all_maps_data: list) -> str:
    """Generate analysis report"""
    report = []
    report.append("# AIRO Map Event Analysis Report\n")
    report.append(f"Analysis Time: {__import__('datetime').datetime.now()}\n\n")
    
    for map_data in all_maps_data:
        if 'error' in map_data:
            continue
        
        map_name = map_data['map']
        report.append(f"## {map_name}\n")
        
        # Unit creation calls
        report.append("### Unit Creation Calls\n")
        if map_data['create_calls']:
            for call in map_data['create_calls']:
                report.append(f"- Line {call['line']}: {call['type']} - {call['context']}\n")
        else:
            report.append("- (No explicit unit creation calls found)\n")
        
        # Triggers
        report.append("\n### Key Triggers\n")
        trigger_names = [t[0] for t in map_data['triggers'][:20]]  # Show first 20
        for trigger in trigger_names:
            report.append(f"- `{trigger}`\n")
        
        # Keywords
        report.append("\n### Event Identification\n")
        for category, occurrences in map_data['keywords'].items():
            if occurrences:
                report.append(f"- **{category}**: Found {len(occurrences)} occurrences\n")
        
        report.append("\n---\n\n")
    
    return ''.join(report)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    all_maps_data = []
    
    # Iterate through all AIRO maps
    if AIRO_MAPS_DIR.exists():
        for map_dir in AIRO_MAPS_DIR.iterdir():
            if map_dir.is_dir() and map_dir.name.endswith('.SC2Map'):
                print(f"Analyzing map: {map_dir.name}...")
                map_data = analyze_map(map_dir)
                all_maps_data.append(map_data)
    
    # Generate Markdown report
    report = generate_report(all_maps_data)
    report_path = OUTPUT_DIR / "map_events_analysis.md"
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report)
    
    # Generate JSON data
    json_path = OUTPUT_DIR / "map_events_analysis.json"
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(all_maps_data, f, ensure_ascii=False, indent=2)
    
    print(f"Analysis complete!")
    print(f"Report saved to: {report_path}")
    print(f"JSON data saved to: {json_path}")


if __name__ == '__main__':
    main()
