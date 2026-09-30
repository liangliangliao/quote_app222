#!/usr/bin/env bash
# 打交付包：版本化 zip，根目录名 beautiful_enemy_v1，随包附 AUDIT.md。
#
# 用法：tools/pack_beautiful_enemy.sh [输出目录]   默认输出到 build/beautiful_enemy/
set -euo pipefail

VERSION="v1"
NAME="beautiful_enemy_${VERSION}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${ROOT}/build/beautiful_enemy}"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

mkdir -p "${OUT_DIR}" "${STAGE}/${NAME}"

# 模块本体（含 AUDIT.md）
cp -R "${ROOT}/lib/beautiful_enemy/." "${STAGE}/${NAME}/"
# 宿主侧装配层：不属于模块，单独放一层，方便对照集成
mkdir -p "${STAGE}/${NAME}/host_integration"
cp -R "${ROOT}/lib/beautiful_enemy_host/." "${STAGE}/${NAME}/host_integration/"
# 测试一并带上
mkdir -p "${STAGE}/${NAME}/test"
cp -R "${ROOT}/test/beautiful_enemy/." "${STAGE}/${NAME}/test/"

ZIP="${OUT_DIR}/${NAME}.zip"
rm -f "${ZIP}"
(cd "${STAGE}" && zip -q -r "${ZIP}" "${NAME}")

echo "打包完成：${ZIP}"
( command -v unzip >/dev/null 2>&1 && unzip -l "${ZIP}" | tail -3 ) || true
