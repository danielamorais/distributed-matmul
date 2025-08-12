import os
from config import DidlReader
from header.generator import HeaderGenerator
from methods.generator import MethodsGenerator
from strategy.generator import StrategyGenerator
from adaptation.generator import AdaptationGenerator
from remote.generator import RemoteGenerator

IDL_EXTENSION = "didl"

idl_resources = []

for (path, dirname, files) in os.walk("resources"):
    for file in files:
        file_extension_type = file.split(".")[-1]
        if file_extension_type != IDL_EXTENSION: continue
        idl_resources.append(path + "/" + file)

for didl_filepath in idl_resources:
    interface_filepath = didl_filepath.replace(f".{IDL_EXTENSION}", ".dn")

    with open(didl_filepath, "r") as didl_file:
        didl_config = DidlReader(didl_file)
        component_implementations = ""

        with open(didl_config.component_file, "r") as component_file:
            component_implementations = component_file.read()

        # verify if outputpath exists
        if not os.path.exists(didl_config.output_folder):
            os.makedirs(didl_config.output_folder)
        
        file_name = didl_filepath.split("/")[-1].replace(f".{IDL_EXTENSION}", ".proxy.dn")
        output_file_path = f"{didl_config.output_folder}/{file_name}"

        strategies = {didl_config.methods[method]['strategy'] for method in didl_config.methods if 'strategy' in didl_config.methods[method]}

        ComponentHeader = HeaderGenerator(interface_filepath, didl_config.dependencies, didl_config.remotes, 'distributed' in strategies)
        ComponentMethods = MethodsGenerator(didl_config.methods, ComponentHeader.get_interface_name(), didl_config.attributes, component_implementations)
        ComponentStrategyAndFooter = StrategyGenerator(strategies)
        ComponentAdaptation = AdaptationGenerator(didl_config.on_active, didl_config.on_inactive)

        with open(output_file_path, "w") as out_file:
            ComponentHeader.provide_component_header(out_file)
            out_file.write("\n")
            ComponentMethods.provide_method_implementation(out_file)
            out_file.write("\n")
            ComponentStrategyAndFooter.provide_strategy(out_file)
            out_file.write("\n")
            ComponentAdaptation.provide_daptation(out_file)
            out_file.write("}\n") # close component scope

        component_name = didl_config.component_file.split('/')[-1].replace(".dn", "").lower()
        component_package = didl_config.component_file.split('/')[-2]
        output_remote_path = f"server/Remote.{component_name}.dn"
        with open(output_remote_path, "w") as out_file:
            remote_generator = RemoteGenerator(file=out_file, component_name=component_name,
                                               component_package=component_package, component_methods=didl_config.methods)
            remote_generator.provide_header()
            remote_generator.break_line()
            remote_generator.provide_server_methods()
            remote_generator.break_line()
            remote_generator.provide_processing_method()
            remote_generator.break_line()
            remote_generator.close_component()
