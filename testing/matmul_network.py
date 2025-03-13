from mininet.net import Containernet
from mininet.node import Controller
from mininet.cli import CLI
from mininet.log import info, setLogLevel

setLogLevel('info')

# Criar rede com Containernet
net = Containernet(controller=Controller)

# Adicionar controlador
net.addController('c0')

# Adicionar elementos da rede
# - 1 cliente (host normal)
h1 = net.addHost('h1') 

# - 2 containers "matmul-remote" com atraso de 5ms
d1 = net.addDocker('d1', dimage="matmul-remote")
d2 = net.addDocker('d2', dimage="matmul-remote")

# - 1 container "matmul-main" com atraso de 5ms
d3 = net.addDocker('d3', dimage="matmul-main")

# - 1 container "matmul-python" com atraso de 20ms
d4 = net.addDocker('d4', dimage="matmul-python")

# Adicionar switch
s1 = net.addSwitch('s1')

# Conectar elementos com atrasos específicos
net.addLink(h1, s1)
net.addLink(d1, s1, params1={'delay': '5ms'})  # Atraso de 5ms
net.addLink(d2, s1, params1={'delay': '5ms'})  # Atraso de 5ms
net.addLink(d3, s1, params1={'delay': '5ms'})  # Atraso de 5ms
net.addLink(d4, s1, params1={'delay': '20ms'}) # Atraso de 20ms

# Iniciar a rede
net.start()

# Testar conectividade
info("Testando conectividade entre todos os nós...\n")
net.pingAll()

# Abrir CLI para interação
CLI(net)

# Parar a rede
net.stop()