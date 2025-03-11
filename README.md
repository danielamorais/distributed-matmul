# Dana application for distributed proxy framework
This is a toy application for testing proxy aproaches on runtime adaptation using dana language

## How to run
- use ```dnc .``` to compile all files and generate binary version
- use ```dana main.o``` to run the main application
- use ```dana RemoteRepo.o``` in another bash to start the remote processor

## Proxy generator
- the definition are made on the resources folder, with dpdl extension files
- see example on ```resources/repositories``` folder
- just run ```python proxy_generator``` on the source and check the output
- to verify the generated file, just check the output path and look for a ```.proxy.dn``` file

## Using Docker
- this application has two docker containers, one (Dockerfile.main) for the main application service, the second (dockerfile.remote) is for the remote component processor, to use those file is simple just run the command:
```docker build -f ./Dockerfile.main -t dana-main-container .```
- to run the main application just use: ```docker run -p 8080:8080 dana-main-container```
- when dealing with many components, you might use different port mapping in your machine, just make sure to map the application ports to available ports in your machine using the following command: ```docker run -p 8081:8082 dana-remote-container```
- there is a build script that you can use to build all containers, and then use ```docker run -p 8080:8080 -it matmul-main``` and  ```docker run -e PORT=8082 -e APP_PORT=2011 -p 8082:8082 matmul-remote``` to run the main and remote