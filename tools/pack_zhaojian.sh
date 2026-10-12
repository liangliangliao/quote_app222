#!/usr/bin/env bash
# 按仓库约定打交付包：版本化 zip，根目录名 zhaojian_v1，随包附 AUDIT.md。
#
# 用法：tools/pack_zhaojian.sh [输出目录]   默认输出到 build/zhaojian/
set -euo pipefail

VERSION="v1"
NAME="zhaojian_${VERSION}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${ROOT}/build/zhaojian}"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

mkdir -p "${OUT_DIR}" "${STAGE}/${NAME}"

# 模块本体（含 AUDIT.md）
cp -R "${ROOT}/lib/zhaojian/." "${STAGE}/${NAME}/"
# 宿主侧装配层：不属于模块，单独放一层，方便对照集成
mkdir -p "${STAGE}/${NAME}/host_integration"
cp -R "${ROOT}/lib/zhaojian_host/." "${STAGE}/${NAME}/host_integration/"
# 测试一并带上，交付方自己就能跑验收
mkdir -p "${STAGE}/${NAME}/test"
cp -R "${ROOT}/test/zhaojian/." "${STAGE}/${NAME}/test/"

ZIP="${OUT_DIR}/${NAME}.zip"
rm -f "${ZIP}"
(cd "${STAGE}" && zip -q -r "${ZIP}" "${NAME}")

echo "打包完成：${ZIP}"
( command -v unzip >/dev/null 2>&1 && unzip -l "${ZIP}" | tail -3 ) || true
