#!/usr/bin/env bash
# 按方案 §11 打交付包：版本化 zip，根目录名 kindling_v1，随包附 AUDIT.md。
#
# 用法：tools/pack_kindling.sh [输出目录]   默认输出到 build/kindling/
set -euo pipefail

VERSION="v1"
NAME="kindling_${VERSION}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${ROOT}/build/kindling}"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

mkdir -p "${OUT_DIR}" "${STAGE}/${NAME}"

# 模块本体（含 AUDIT.md）
cp -R "${ROOT}/lib/kindling/." "${STAGE}/${NAME}/"
# 宿主侧装配层：不属于模块，单独放一层，方便对照集成
mkdir -p "${STAGE}/${NAME}/host_integration"
cp -R "${ROOT}/lib/kindling_host/." "${STAGE}/${NAME}/host_integration/"
# 测试一并带上，交付方自己就能跑验收
mkdir -p "${STAGE}/${NAME}/test"
cp -R "${ROOT}/test/kindling/." "${STAGE}/${NAME}/test/"

ZIP="${OUT_DIR}/${NAME}.zip"
rm -f "${ZIP}"
(cd "${STAGE}" && zip -q -r "${ZIP}" "${NAME}")

echo "打包完成：${ZIP}"
( command -v unzip >/dev/null 2>&1 && unzip -l "${ZIP}" | tail -3 ) || true
