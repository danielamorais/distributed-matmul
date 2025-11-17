echo Deleting previous build artifacts...
if [ -d wasm_output ]; then
  rm -rf wasm_output
fi
if [ -f webserver/file_system.js ]; then
  rm -f webserver/file_system.js
fi