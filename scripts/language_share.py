"""Count first-party code bytes, including tests, without language relabeling."""
from pathlib import Path
import json
root = Path(__file__).resolve().parents[1]
extensions = {'.sol', '.ts', '.tsx', '.js', '.cjs', '.mjs', '.py', '.html', '.css'}
counts = {}
for path in root.rglob('*'):
    if not path.is_file() or any(part in {'node_modules', 'artifacts', 'cache', 'vendor', '.git'} for part in path.parts):
        continue
    if path.name in {'config.js', 'abi.json'} or path.suffix not in extensions:
        continue
    counts[path.suffix] = counts.get(path.suffix, 0) + path.stat().st_size
share = counts.get('.sol', 0) / sum(counts.values()) * 100
print(json.dumps({'code_bytes': counts, 'solidity_percent': round(share, 2)}, indent=2))
if share < 50:
    raise SystemExit('Solidity is below 50%')
