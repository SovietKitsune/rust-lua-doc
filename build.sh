#!/usr/bin/env sh

# Clean

# These are copied
rm -rf out/packages/tealdoc-cli/{templates,assets}
# rm -rf out/pl

# Build

# tl run scripts/check.tl $(find ./packages -type f -name "*.tl")
tl check $(find ./packages -type f -name "*.tl")

cyan build

# Copy

cp -r packages/tealdoc-cli/{templates,assets} out/packages/tealdoc-cli/
# cp -r src/pl out/pl
