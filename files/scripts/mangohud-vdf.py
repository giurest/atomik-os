#!/usr/bin/env python3
# Inietta 'mangohud %command%' nelle launch options vuote dei giochi Steam
# installati. Legge gli appid installati da stdin (uno per riga).
# Uso: <appid_list> | mangohud-vdf.py /path/localconfig.vdf
import sys, re

vdf_path = sys.argv[1]
installed = set(line.strip() for line in sys.stdin if line.strip())

# Tool/runtime Steam che NON sono giochi (mai mangohud)
TOOL_IDS = {
    "228980",   # Steamworks Common Redistributables
    "1070560",  # Steam Linux Runtime 1.0 (Scout)
    "1391110",  # Steam Linux Runtime 2.0 (Soldier)
    "1493710",  # Proton Experimental
    "1628350",  # Steam Linux Runtime 3.0 area
    "1774580",  # Steam Linux Runtime 3.0 (Sniper)
    "4183110",  # runtime/tool Proton recente
}

with open(vdf_path, 'r', encoding='utf-8', errors='replace') as f:
    lines = f.readlines()
n = len(lines)

def is_appid_line(line):
    return bool(re.fullmatch(r'"\d+"', line.strip()))

result = []
idx = 0
added = 0
skipped_opts = 0
skipped_notinstalled = 0
skipped_tool = 0
while idx < n:
    line = lines[idx]
    result.append(line)
    if is_appid_line(line):
        appid = line.strip().strip('"')
        j = idx + 1
        while j < n and lines[j].strip() == "":
            result.append(lines[j]); j += 1
        if j < n and lines[j].strip() == "{":
            result.append(lines[j])
            brace_depth = 1
            block_lines = []
            k = j + 1
            while k < n and brace_depth > 0:
                stripped = lines[k].strip()
                if stripped == "{":
                    brace_depth += 1
                elif stripped == "}":
                    brace_depth -= 1
                    if brace_depth == 0:
                        break
                block_lines.append(lines[k]); k += 1

            apply = True
            if appid not in installed:
                apply = False; skipped_notinstalled += 1
            elif appid in TOOL_IDS:
                apply = False; skipped_tool += 1

            if apply:
                indent = "\t\t\t\t\t\t"
                for b in block_lines:
                    m = re.match(r'^(\t+)"', b)
                    if m:
                        indent = m.group(1); break
                launch_idx = None
                launch_val = None
                for bi, b in enumerate(block_lines):
                    mm = re.search(r'"LaunchOptions"\s*"(.*)"', b)
                    if mm:
                        launch_idx = bi; launch_val = mm.group(1); break
                if launch_idx is None:
                    block_lines.insert(0, indent + '"LaunchOptions"\t\t"mangohud %command%"\n')
                    added += 1
                elif launch_val.strip() == "":
                    block_lines[launch_idx] = re.sub(
                        r'("LaunchOptions"\s*")(")',
                        r'\1mangohud %command%\2', block_lines[launch_idx])
                    added += 1
                else:
                    skipped_opts += 1

            result.extend(block_lines)
            result.append(lines[k])
            idx = k + 1
            continue
    idx += 1

with open(vdf_path, 'w', encoding='utf-8') as f:
    f.writelines(result)

print(f"  mangohud aggiunto:          {added}")
print(f"  saltati (gia opzioni):      {skipped_opts}")
print(f"  saltati (tool/runtime):     {skipped_tool}")
print(f"  ignorati (non installati):  {skipped_notinstalled}")
