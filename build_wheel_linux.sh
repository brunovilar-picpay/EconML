#!/bin/bash
# Build EconML wheel para Linux x86_64 (Databricks) via Docker
# Uso: ./build_wheel_linux.sh
#
# Pré-requisito: Docker Desktop rodando

set -e

echo "🔨 Building EconML wheel for Linux x86_64 (Databricks-compatible)..."

# Limpa dist anterior
rm -rf dist_linux
mkdir -p dist_linux

# Build usando manylinux2014 (compatível com Databricks)
docker run --rm --platform linux/amd64 \
  -v "$(pwd)":/io \
  -w /io \
  quay.io/pypa/manylinux2014_x86_64 \
  /bin/bash -c "
    set -e
    echo '📦 Installing build dependencies...'
    /opt/python/cp310-cp310/bin/pip install --upgrade pip setuptools wheel 'numpy>=2,<3' scipy cython

    echo '🏗️ Building wheel...'
    /opt/python/cp310-cp310/bin/pip wheel . --no-deps -w /tmp/dist

    echo '🔧 Auditing wheel (auditwheel repair)...'
    /opt/python/cp310-cp310/bin/pip install auditwheel
    /opt/python/cp310-cp310/bin/auditwheel repair /tmp/dist/*.whl -w /io/dist_linux/ --plat manylinux2014_x86_64 || \
      cp /tmp/dist/*.whl /io/dist_linux/

    echo '✅ Done!'
  "

echo ""
echo "📁 Wheel gerado:"
ls -lh dist_linux/*.whl
echo ""
echo "🚀 Para instalar no Databricks:"
echo "   %pip install /dbfs/path/to/$(ls dist_linux/*.whl | head -1 | xargs basename)"
