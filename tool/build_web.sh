#!/usr/bin/env bash
# Builds the web app with its version stamped in, so Profile and support
# messages show which build a parent is running.
#
#   version  from pubspec.yaml (the part before "+")
#   build    the number of commits on this branch: it goes up with every
#            deploy without anyone editing a file
#
# Extra arguments go to flutter, e.g. a local backend:
#   tool/build_web.sh --dart-define=API_BASE_URL=http://localhost:8000
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml)
build=$(git rev-list --count HEAD)

flutter build web \
  --build-name="$version" --build-number="$build" \
  --dart-define=APP_VERSION="$version" --dart-define=APP_BUILD="$build" \
  "$@"

echo "Built Nuvora $version (build $build)"
