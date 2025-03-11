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
