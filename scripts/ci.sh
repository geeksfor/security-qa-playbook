## D6：本地/CI 一键脚本

### `scripts/ci.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] forge fmt (check)"
forge fmt --check

echo "[2/3] forge test"
forge test -vvv

echo "[3/3] forge coverage"
forge coverage
