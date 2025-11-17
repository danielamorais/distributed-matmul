./clean-wasm.sh

echo Compiling Dana files...
./compile-wasm.sh
echo Packaging WASM files...
./package-wasm.sh

echo Starting remote workers...
# To run these in separate terminal windows, you can use x-terminal-emulator, gnome-terminal, or xterm.
# Here's an example using gnome-terminal:
gnome-terminal -- bash -c "dana app/RemoteRepo.o 8081 9000; exec bash"
gnome-terminal -- bash -c "dana app/RemoteRepo.o 8082 9001; exec bash"
# If you want to use a different terminal application, replace 'gnome-terminal' with your preferred one.
export MATMUL_UPSTREAMS="http://localhost:8081/rpc,http://localhost:8082/rpc"   

echo Running web server...
node webserver/server.js
