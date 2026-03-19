#!/bin/bash
# ============================================================
# Build EconML wheel para Databricks Graviton (ARM64)
# ============================================================
# Uso: ./build_wheel_databricks.sh
#
# Target: Python 3.11 + linux/arm64 (Databricks Graviton)
# Pré-requisito: Docker rodando
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 EconML Databricks Wheel Builder"
echo "===================================="
echo ""

if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker não está rodando."
  exit 1
fi

rm -rf dist_databricks
mkdir -p dist_databricks

PYVER="cp311-cp311"
DOCKER_PLATFORM="linux/arm64"
PLAT_TAG="manylinux_2_28_aarch64"
DOCKER_IMAGE="quay.io/pypa/manylinux_2_28_aarch64"

echo "🏗️  Target: Python 3.11 | ARM64 | ${PLAT_TAG}"
echo ""

docker run --rm --platform "${DOCKER_PLATFORM}" \
  -v "${SCRIPT_DIR}":/io \
  -w /io \
  "${DOCKER_IMAGE}" \
  /bin/bash -c "
    set -e

    PIP=/opt/python/${PYVER}/bin/pip
    PYTHON=/opt/python/${PYVER}/bin/python

    echo '📦 Upgrading pip + build tools...'
    \$PIP install --upgrade pip setuptools>=68.0 wheel>=0.41 2>&1 | tail -3

    echo ''
    echo '🔧 Building wheel (with build isolation)...'
    # pip wheel COM isolation: pip instala as build deps do pyproject.toml
    # automaticamente num venv temporário
    \$PIP wheel /io --no-deps -w /tmp/wheelhouse 2>&1 | tail -10

    echo ''
    echo '📋 Wheel gerado:'
    ls -lh /tmp/wheelhouse/*.whl

    echo ''
    echo '🔧 auditwheel repair...'
    \$PIP install auditwheel patchelf 2>&1 | tail -1
    /opt/python/${PYVER}/bin/auditwheel repair /tmp/wheelhouse/*.whl \
      -w /io/dist_databricks/ \
      --plat ${PLAT_TAG} 2>&1 | tail -5 || {
        echo '⚠️ auditwheel falhou, copiando wheel original...'
        cp /tmp/wheelhouse/*.whl /io/dist_databricks/
      }

    echo ''
    echo '✅ Build completo!'
  "

echo ""
echo "======================================="
echo "📁 Wheel gerado:"
echo "======================================="
ls -lh dist_databricks/*.whl
echo ""
echo "📌 Instalar no Databricks:"
WHEEL_NAME=$(ls dist_databricks/*.whl | head -1 | xargs basename)
echo "   %pip install /dbfs/path/to/${WHEEL_NAME}"
