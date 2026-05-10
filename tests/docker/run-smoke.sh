#!/bin/sh
# run-smoke.sh — orquestrador host-side: build + run do smoke test.
#
# Uso:
#   tests/docker/run-smoke.sh [VERSION]
#
# Default VERSION = 3.5.0. Espera tarball ja construido em
# dist/cstk-VERSION.tar.gz (rode `scripts/build-release.sh vVERSION` antes).

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VERSION=${1:-3.5.0}
TARBALL="$REPO_ROOT/dist/cstk-${VERSION}.tar.gz"
INSTALLER="$REPO_ROOT/cli/install.sh"

if [ ! -f "$TARBALL" ]; then
  printf 'erro: tarball ausente em %s\n' "$TARBALL" >&2
  printf 'rode antes: scripts/build-release.sh v%s\n' "$VERSION" >&2
  exit 1
fi
if [ ! -f "$INSTALLER" ]; then
  printf 'erro: installer ausente em %s\n' "$INSTALLER" >&2
  exit 1
fi

IMAGE="cstk-smoke:${VERSION}"

printf '==> docker build %s\n' "$IMAGE"
docker build -t "$IMAGE" -f "$REPO_ROOT/tests/docker/Dockerfile.smoke" \
  "$REPO_ROOT/tests/docker"

printf '\n==> docker run smoke (v%s)\n' "$VERSION"
docker run --rm \
  -e EXPECTED_VERSION="$VERSION" \
  -v "$REPO_ROOT/dist:/fixtures:ro" \
  -v "$INSTALLER:/installer/install.sh:ro" \
  -v "$REPO_ROOT/tests/docker/smoke.sh:/smoke/smoke.sh:ro" \
  "$IMAGE" \
  sh /smoke/smoke.sh
