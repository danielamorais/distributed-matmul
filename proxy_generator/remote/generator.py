
def use_identation(func):
    def identation_wrapper(self, *args, **kwargs):
        self.ident()
        func(self, *args, **kwargs)
        self.break_line()
    return identation_wrapper

def use_flow(flow: str):
    def use_flow_dec(func):
        def flow_wrapper(self, *args, **kwargs):
            self.ident()
            self.file.write(flow)
            self.file.write(" {")
            self.break_line()
            self.improve_identation_level()
            func(self, *args, **kwargs)
            self.close_component()
        return flow_wrapper
    return use_flow_dec

replicated_strategies = ['distribute']

class RemoteGenerator:
    def __init__(self, file, component_name, component_package,
                 component_methods,
                 identation_level=0, connection_library="network.rpc.RPCUtil rpc"):
        self.identation_level = identation_level
        self.file = file
        self.component_name = component_name
        self.component_package = component_package
        self.component_methods = component_methods
        self.resources = [
            "net.TCPSocket",
            "net.TCPServerSocket",
            "io.Output out",
            "data.IntUtil iu",
            "data.json.JSONEncoder je",
            "data.StringUtil su",
            connection_library,
            f"{component_package}.{component_name.capitalize()} remoteComponent",
        ]
    
    def provide_header(self):
        self.file.write("uses Constants")
        self.break_line()
        self.file.write('const char debugMSG[] = "[@Remote]"')
        self.break_line()
        self.break_line()
        self.ident()
        self.file.write(f"component provides server.Remote:{self.component_name} {self.provide_component_resources()}" + " {")
        self.improve_identation_level()

    def provide_component_resources(self):
        return "requires " + ", ".join(self.resources)

    def provide_server_methods(self):
        self.write_idented("bool serviceStatus = false")
        self.break_line()
        self.provie_init_method()
        self.provide_handle_request()
    
    @use_flow("void Remote:start(int PORT)")
    def provie_init_method(self):
        self.write_idented("TCPServerSocket host = new TCPServerSocket()")
        self.write_idented("serviceStatus = true")
        self.break_line()
        inside_if = self.use_idented_flow("if (!host.bind(TCPServerSocket.ANY_ADDRESS, PORT))")
        inside_if(self, [
            'out.println("Error: failed to bind master socket")',
            "return"
        ])
        self.write_idented('out.println("$debugMSG - Server started on port $(iu.makeString(PORT))")')
        self.break_line()
        inside_while = self.use_idented_flow("while (serviceStatus)")
        inside_while(self, [
            "TCPSocket client = new TCPSocket()",
            "if (client.accept(host)) asynch::handleRequest(client)"
        ])

    @use_flow("void Remote:handleRequest(TCPSocket s)")
    def provide_handle_request(self):
        self.write_idented("char requestContent[] = rpc.receiveData(s)")
        self.write_idented("if(requestContent == null) s.disconnect()")
        self.write_idented("Request req = rpc.parseRequestFromString(requestContent)")
        self.write_idented("Response res = process(req)")
        self.write_idented("char rawResponse[] = rpc.buildRawResponse(res)")
        self.write_idented("s.send(rawResponse)")
        self.write_idented("s.disconnect()")

    @use_flow("Response process(Request req)")
    def provide_processing_method(self):
        self.write_idented("char method[] = rpc.getMethodFromMetadata(req.meta)")
        self.break_line()
        # methods goes here
        for method in self.component_methods:
            method_configs = self.component_methods[method]
            # print(method_configs)
            if method_configs["strategy"] in replicated_strategies:
                inside_strategy = self.use_idented_flow(f'if(method == "{method}")')
                parameters_format_type = f"{method[0].upper() + method[1:]}ParamsFormat"
                inside_strategy(self, [
                    f"{parameters_format_type} paramsData = je.jsonToData(req.content, typeof({parameters_format_type}))",
                    f"{method_configs['returnType']} result = remoteComponent.{method}({self.provide_virables_for_method(method_configs)})",
                    f'return rpc.buildResponseWithData("{method}", "200", remoteComponent.{method_configs["remoteReturnParser"].format("result")})'
                ])

        # finish methods
        # default response
        self.write_idented('return rpc.buildResponse(method, "404")')
        # end default response

    def provide_virables_for_method(self, method_config) -> str:
        def get_formated_parser(param):
            return param['variableParser'].format(f"paramsData.{param['name']}")

        return ",".join([f"remoteComponent.{get_formated_parser(param)}" for param in method_config['parameters']])

    @use_identation
    def write_idented(self, line: str):
        self.file.write(line)
    
    def use_idented_flow(self, flow: str):
        @use_flow(flow)
        def flow_writer(self, lines: list):
            for line in lines:
                self.write_idented(line)
        return flow_writer

    def ident(self):
        self.file.write(self.identation_level * "\t")

    def improve_identation_level(self):
        self.identation_level += 1

    def deteriorate_identation_level(self):
        self.identation_level -= 1

    def break_line(self):
        self.file.write("\n")

    def close_component(self):
        self.deteriorate_identation_level()
        self.ident()
        self.file.write("}")
        self.break_line()
        self.break_line()

    
