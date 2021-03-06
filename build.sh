#!/usr/bin/env sh

# Clean

rm -rf out
mkdir out

# Build

cyan check src/tealdoc/*.tl
cyan build

# Copy

cp -r src/tealdoc/templates out/tealdoc/templates
