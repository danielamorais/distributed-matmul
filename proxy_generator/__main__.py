import os
from config import DpdlReader
from header.generator import HeaderGenerator
from methods.generator import MethodsGenerator
from strategy.generator import StrategyGenerator
from adaptation.generator import AdaptationGenerator

IDL_EXTENSION = "dpdl"

idl_resources = []

for (path, dirname, files) in os.walk("resources"):
    for file in files:
        file_extension_type = file.split(".")[-1]
        if file_extension_type != IDL_EXTENSION: continue
        idl_resources.append(path + "/" + file)

for dpdl_filepath in idl_resources:
    interface_filepath = dpdl_filepath.replace(".dpdl", ".dn")

    with open(dpdl_filepath, "r") as dpdl_file:
        dpdl_config = DpdlReader(dpdl_file)
        component_implementations = ""

        with open(dpdl_config.component_file, "r") as component_file:
            component_implementations = component_file.read()

        # verify if outputpath exists
        if not os.path.exists(dpdl_config.output_folder):
            os.makedirs(dpdl_config.output_folder)
        
        file_name = dpdl_filepath.split("/")[-1].replace(".dpdl", ".proxy.dn")
        output_file_path = f"{dpdl_config.output_folder}/{file_name}"

        strategies = {dpdl_config.methods[method]['strategy'] for method in dpdl_config.methods if 'strategy' in dpdl_config.methods[method]}

        ComponentHeader = HeaderGenerator(interface_filepath, dpdl_config.dependencies, dpdl_config.remotes, 'distributed' in strategies)
        ComponentMethods = MethodsGenerator(dpdl_config.methods, ComponentHeader.get_interface_name(), dpdl_config.attributes, component_implementations)
        ComponentStrategyAndFooter = StrategyGenerator(strategies)
        ComponentAdaptation = AdaptationGenerator(dpdl_config.on_active, dpdl_config.on_inactive)

        with open(output_file_path, "w") as out_file:
            ComponentHeader.provide_component_header(out_file)
            out_file.write("\n")
            ComponentMethods.provide_method_implementation(out_file)
            out_file.write("\n")
            ComponentStrategyAndFooter.provide_strategy(out_file)
            out_file.write("\n")
            ComponentAdaptation.provide_daptation(out_file)
            out_file.write("}\n") # close component scope
