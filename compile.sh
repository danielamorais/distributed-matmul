#!/bin/bash
echo "Generating proxy..."
python3 proxy_generator
echo "Compiling Dana files..."
# Compile only component files, excluding interfaces in resources/
find . -name "*.dn" -type f \
    ! -path "./resources/*" \
    ! -path "./wasm_output/*" \
    ! -path "./webserver/*" \
    ! -path "./.git/*" \
    ! -path "./results/*" \
    ! -path "./testing/*" \
    ! -path "./proxy_generator/*" \
    -exec dnc {} \;
echo "Compilation complete"