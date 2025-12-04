#!/bin/bash
echo "Generating proxy..."
python3 proxy_generator
echo "Compiling Dana files..."
dnc .
echo "Compilation complete"