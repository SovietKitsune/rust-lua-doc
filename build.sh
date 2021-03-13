#!/usr/bin/env sh

# Clean

rm -rf out
mkdir out

# Build

tl run scripts/check.tl $(find ./src/tealdoc/ -type f -name "*.tl")
cyan build

# Copy

cp -r src/tealdoc/templates out/tealdoc/templates
cp -r src/pl out/pl
