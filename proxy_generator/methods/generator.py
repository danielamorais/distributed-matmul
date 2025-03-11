import re

METHOD_TABS = '\t\t'

class MethodsGenerator:
    def __init__(self, methods, interface_name, attributes, component_implementations):
        self.methods = methods
        self.interface_name = interface_name
        self.attributes = attributes
        self.component_implementations = component_implementations

    def provide_method_implementation(self, file):
        self.provide_methods(file)
        self.provide_metadata_factory(file)

    def provide_methods(self, file):
        for method in self.methods:
            method_props = self.methods[method]

            builder = MethodBuilder(method, method_props, self.interface_name, file)
            builder.look_on_arguments()
            if method_props['strategy'] == 'local':
                escaped_return_type = re.escape(method_props['returnType'])
                escaped_interface = re.escape(self.interface_name)
                escaped_method = re.escape(method)
    
                # Constrói o padrão regex dinamicamente
                pattern = (
                    escaped_return_type + ' ' + escaped_interface + ':' + escaped_method + r'\([^)]*\)\s*{\n'  # Cabeçalho do método
                    r'([\s\S]*?)'  # Captura o conteúdo entre as chaves (incluindo novas linhas)
                    r'\n    }'  # Fecha a chave do método (indentação de 4 espaços)
                )
                method_implementation_code = re.search(pattern, self.component_implementations)
                if method_implementation_code: builder.generate_method_code(method, method_props,
                                                                            component_code=method_implementation_code.group(1))
            else:
                builder.generate_method_code(method, method_props)

            file.write("\t}\n")
            file.write("\n")
    
    def provide_strategy_call_for_order(self, file, order, strategy):
        file.write("{}(req{})\n".format(strategy, order))

    def provide_metadata_factory(self, file):
        file.write("""\tMetadata[] buildMetaForMethod(char method[]) {\n\t\tMetadata metaMethod = new Metadata("method", method)\n\t\treturn new Metadata[](metaMethod)\n\t}\n""")

class MethodBuilder:
    def __init__(self, name, props, interface_name, file):
        self.name = name
        self.props = props
        self.interface_name = interface_name
        self.file = file

        file.write(f"\t{props['returnType']} {self.interface_name}:{name}(")

    def look_on_arguments(self):
        if 'parameters' in self.props:
            for i, arg in enumerate(self.props['parameters']):
                arg_string = ""
                if 'store' in arg and arg['store']: arg_string += "store "
                
                if "[]" in arg['type']: arg_string += f"{arg['type'].replace('[]', '')} {arg['name']}[]"
                else: arg_string += f"{arg['type']} {arg['name']}"
                
                self.file.write(arg_string)
                if i != len(self.props['parameters']) - 1: self.file.write(", ")

        self.file.write(") {\n")

    def generate_method_code(self, method_name: str, props, component_code: str | None = None):
        if component_code != None:
            self.file.write(component_code)
            self.file.write("\n")
        elif 'strategy' in props and props['strategy'] == 'distribute':
            param_format_name = method_name[0].upper() + method_name[1:]
            params_formatter = f'{param_format_name}ParamsFormat params = new {param_format_name}ParamsFormat('
            for index, param in enumerate(props['parameters'] if 'parameters' in props else []):
                if 'stringParser' in param: params_formatter += param['stringParser'].format(
                    param['useFormat'] if 'useFormat' in param else param['name'])
                else:
                    params_formatter += param['name']
                
                if index != len(props['parameters']) - 1: params_formatter += ', '
            params_formatter += ")\n"

            self.file.write(METHOD_TABS)
            self.file.write(params_formatter)
            self.file.write(METHOD_TABS)
            self.file.write("char requestBody[] = je.jsonFromData(params)\n")
            self.file.write(METHOD_TABS)
            self.file.write('Request req = new Request(buildMetaForMethod("{}"), requestBody)\n'.format(method_name))
            self.file.write(METHOD_TABS)
            self.file.write("Response res = {}(req)\n".format(props['strategy']))
            self.file.write(METHOD_TABS)
            self.file.write("return {}\n".format(props['returnParser'].format('res.content') if 'returnParser' in props else 'res.content'))
        else: # read / write operations
            if 'parameters' in props and len(props['parameters']) == 1:
                self.file.write(METHOD_TABS)
                self.file.write("char requestBody[] = je.jsonFromData({})\n".format(props['parameters'][0]['name']))
                self.file.write(METHOD_TABS)
                self.file.write('Request req = new Request(buildMetaForMethod("{}"), requestBody)\n'.format(method_name))
            elif 'parameters' in props and len(props['parameters']) > 1:
                pass
            else:    
                self.file.write(METHOD_TABS)
                self.file.write('Request req = new Request(buildMetaForMethod("{}"))\n'.format(method_name))

            self.file.write(METHOD_TABS)
            self.file.write('{}{}{}(req)\n'.format(
                'Response res = ' if props['returnType'] != 'void' else '',
                props['strategy'],
                props['operation'].capitalize()))
            
            if props['returnType'] != 'void':
                self.file.write(METHOD_TABS)
                self.file.write('return {}\n'.format(props['useParser'].format('res.content') if 'useParser' in props else 'res.content'))
                


    def build_request(method_name, content=None) -> str:
        if content == None:
            return "new Request(buildMetaForMethod(\"{}\"))\n".format(method_name)
        else:
            return "new Request(buildMetaForMethod(\"{}\"), {})\n".format(method_name, content)

