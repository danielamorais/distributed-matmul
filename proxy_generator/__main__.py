import os
from config import DpdlReader
from header.generator import HeaderGenerator
from methods.generator import MethodsGenerator
from strategy.generator import StrategyGenerator
from adaptation.generator import AdaptationGenerator

IDL_EXTENSION = "didl"

idl_resources = []

for (path, dirname, files) in os.walk("resources"):
    for file in files:
        file_extension_type = file.split(".")[-1]
        if file_extension_type != IDL_EXTENSION: continue
        idl_resources.append(path + "/" + file)

for didl_filepath in idl_resources:
    interface_filepath = didl_filepath.replace(".didl", ".dn")

    with open(didl_filepath, "r") as didl_file:
        didl_config = DpdlReader(didl_file)
        component_implementations = ""

        with open(didl_config.component_file, "r") as component_file:
            component_implementations = component_file.read()

        # verify if outputpath exists
        if not os.path.exists(didl_config.output_folder):
            os.makedirs(didl_config.output_folder)
        
        file_name = didl_filepath.split("/")[-1].replace(".didl", ".proxy.dn")
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
