#!/bin/bash
# ============================================================
# Build EconML wheels para múltiplas plataformas via Docker
# ============================================================
# Uso: ./build_wheels_multi.sh
#
# Gera wheels para:
#   - linux/amd64  (Databricks, servidores x86_64)
#   - linux/arm64  (Graviton, ARM servers)
#
# Pré-requisito: Docker Desktop rodando
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 EconML Multi-Platform Wheel Builder"
echo "======================================="
echo ""

# Verificar Docker
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker não está rodando. Inicie o Docker Desktop e tente novamente."
  exit 1
fi

# Limpar output
rm -rf dist_multiplatform
mkdir -p dist_multiplatform

# -----------------------------------------------
# Versões Python pra buildar (Databricks usa 3.10/3.11)
# -----------------------------------------------
PYTHON_VERSIONS=("cp310-cp310" "cp311-cp311")

# -----------------------------------------------
# Plataformas
# -----------------------------------------------
PLATFORMS=(
  "linux/amd64|manylinux2014_x86_64|quay.io/pypa/manylinux2014_x86_64"
  "linux/arm64|manylinux2014_aarch64|quay.io/pypa/manylinux2014_aarch64"
)

for PLATFORM_ENTRY in "${PLATFORMS[@]}"; do
  IFS='|' read -r DOCKER_PLATFORM PLAT_TAG DOCKER_IMAGE <<< "$PLATFORM_ENTRY"

  for PYVER in "${PYTHON_VERSIONS[@]}"; do
    PYTHON_BIN="/opt/python/${PYVER}/bin/python"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏗️  Building: ${PYVER} | ${DOCKER_PLATFORM}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    docker run --rm --platform "${DOCKER_PLATFORM}" \
      -v "${SCRIPT_DIR}":/io \
      -w /io \
      "${DOCKER_IMAGE}" \
      /bin/bash -c "
        set -e

        PYTHON=/opt/python/${PYVER}/bin/python
        PIP=/opt/python/${PYVER}/bin/pip

        echo '📦 Instalando dependências de build...'
        \$PIP install --upgrade pip setuptools wheel 'numpy>=2,<3' scipy cython 2>&1 | tail -3

        echo '🔧 Compilando wheel...'
        \$PIP wheel /io --no-deps --no-build-isolation -w /tmp/wheelhouse 2>&1 | tail -5

        echo '🔍 Auditando wheel (auditwheel)...'
        \$PIP install auditwheel 2>&1 | tail -1
        /opt/python/${PYVER}/bin/auditwheel repair /tmp/wheelhouse/*.whl \
          -w /io/dist_multiplatform/ \
          --plat ${PLAT_TAG} 2>&1 | tail -3 || \
          cp /tmp/wheelhouse/*.whl /io/dist_multiplatform/

        echo '✅ Done: ${PYVER} | ${DOCKER_PLATFORM}'
      "
  done
done

echo ""
echo "======================================="
echo "📁 Wheels gerados:"
echo "======================================="
ls -lh dist_multiplatform/*.whl 2>/dev/null || echo "Nenhum wheel encontrado!"
echo ""
echo "🚀 Para instalar no Databricks (Linux x86_64):"
echo "   %pip install /dbfs/path/to/<wheel_manylinux2014_x86_64>.whl"
echo ""
echo "🚀 Para instalar em ARM (Graviton/M-series containers):"
echo "   %pip install /dbfs/path/to/<wheel_manylinux2014_aarch64>.whl"
