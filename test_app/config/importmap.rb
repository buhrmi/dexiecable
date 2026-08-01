# Pin npm packages by running ./bin/importmap

pin "application"

# Dexie from CDN (esm.sh provides proper ESM exports)
pin "dexie", to: "https://esm.sh/dexie@4.0.4"

# DexieCable as a concatenated bundle (built from symlinked source files)
pin "dexiecable", to: "dexiecable-bundle.js"
