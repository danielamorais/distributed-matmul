STRATEGIES_CODE = {
    "broadcast": {
        "write": """\t\tfor(int i = 0; i < remotes.arrayLength; i++) {\n\t\t\tconnection.connect(remotes[i])\n\t\t\tconnection.make(r)\n\t\t}\n""",
        "read": """\t\tconnection.connect(remotes[0])\n\t\treturn connection.make(r)\n"""
    },
    "distribute": "\t\tconnection.connect(remotes[addressPointer])\n\t\tmutex(pointerLock) {\n\t\t\taddressPointer++\n\t\t\tif(addressPointer >= remotes.arrayLength) addressPointer = 0\n\t\t}\n\t\treturn connection.make(r)\n",
}

class StrategyGenerator():
    def __init__(self, strategies):
        self.strategies = strategies

    def provide_strategy(self, file):
        for strategy in self.strategies:
            if strategy in STRATEGIES_CODE and strategy != 'local':
                if 'write' in STRATEGIES_CODE[strategy] and 'read' in STRATEGIES_CODE[strategy]:
                    write_strategy_method_name = "{}Write".format(strategy)
                    read_strategy_method_name = "{}Read".format(strategy)

                    #write writeStrategy
                    file.write("\tvoid {}(Request r) ".format(write_strategy_method_name) + "{\n")
                    file.write(STRATEGIES_CODE[strategy]["write"])
                    file.write("\t}\n")

                    file.write("\n")

                    # write readStrategy
                    file.write("\tResponse {}(Request r) ".format(read_strategy_method_name) + "{\n")
                    file.write(STRATEGIES_CODE[strategy]["read"])
                    file.write("\t}\n")
                else:
                    file.write("\tResponse {}(Request r) ".format(strategy) + "{\n")
                    file.write(STRATEGIES_CODE[strategy])
                    file.write("\t}\n")