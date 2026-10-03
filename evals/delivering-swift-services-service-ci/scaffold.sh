#!/bin/bash
set -euo pipefail
case_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -R "$case_dir/fixture/." .
