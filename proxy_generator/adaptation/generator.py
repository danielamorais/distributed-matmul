
class AdaptationGenerator:
    def __init__(self, on_active, on_inactive):
        self.on_active = on_active
        self.on_inactive = on_inactive

    def provide_daptation(self, file):
        self.provide_on_active(file)
        file.write("\n")
        self.provide_on_inactive(file)
    
    def provide_on_active(self, file):
        file.write("\tvoid AdaptEvents:active() {\n")
        for instruction in self.on_active:
            if "call" in instruction and "forEachElementIn" in instruction:
                file.write("\t\tfor(int i=0;i<{}.arrayLength;i++)".format(instruction["forEachElementIn"]))
                file.write(" {\n")
                file.write("\t\t\t{}({}[i])\n".format(instruction['call'], instruction['forEachElementIn']))
                file.write("\t\t}\n")

        file.write("\t}\n")
    
    def provide_on_inactive(self, file):
        file.write("\tvoid AdaptEvents:inactive() {\n")
        for instruction in self.on_inactive:
            if "call" in instruction:
                file.write("\t\t{}()\n".format(instruction['call']))
            elif "assignTo" in instruction and "value" in instruction:
                file.write("\t\t{} = {}\n".format(instruction['assignTo'], instruction['value']))
        file.write("\t}\n")