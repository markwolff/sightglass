#!/bin/sh
set -eu

mkdir -p .context

swift build --product Sightglass
swift run SightglassHarness verify --benchmark-output .context/benchmarks.json "$@"
