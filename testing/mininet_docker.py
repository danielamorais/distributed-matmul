from mininet.net import Containernet
from mininet.node import Docker, RemoteController
from mininet.cli import CLI
from mininet.link import TCLink

def create_network():
    net = Containernet(controller=RemoteController, link=TCLink)

    # Controlador
    c0 = net.addController('c0', ip='127.0.0.1', port=6653)

    # Hosts Docker (nomes curtos)
    dana_main = net.addHost('dana-main', cls=Docker, ip='10.0.0.1', dimage="distributed-matmul-dana-main")
    remote1 = net.addHost('remote1', cls=Docker, ip='10.0.0.2', dimage="distributed-matmul-dana-remote-1")  # Nome curto
    remote2 = net.addHost('remote2', cls=Docker, ip='10.0.0.3', dimage="distributed-matmul-dana-remote-2")  # Nome curto
    locust = net.addHost('locust', cls=Docker, ip='10.0.0.4', dimage="distributed-matmul-locust-test")       # Nome curto
    serial = net.addHost('serial', cls=Docker, ip='10.0.0.5', dimage="distributed-matmul-serial-matmul")    # Nome curto
    locust_serial = net.addHost('locust-ser', cls=Docker, ip='10.0.0.6', dimage="distributed-matmul-locust-test-serial")

    # Switches
    s1 = net.addSwitch('s1')
    s2 = net.addSwitch('s2')

    # Links (ajustados para os novos nomes)
    net.addLink(dana_main, s1, bw=10, delay='6ms', loss=1)
    net.addLink(remote1, s1, bw=5, delay='1ms', loss=2)  # Nome corrigido: remote1
    net.addLink(remote2, s1, bw=5, delay='1ms', loss=2)  # Nome corrigido: remote2
    net.addLink(locust, s1, bw=15, delay='2ms', loss=0.5)
    net.addLink(serial, s2, bw=20, delay='20ms', loss=0.1)
    net.addLink(locust_serial, s2, bw=15, delay='2ms', loss=0.5)
    net.addLink(s1, s2, bw=50, delay='1ms', loss=0.1)

    net.start()
    CLI(net)
    net.stop()

if __name__ == '__main__':
    create_network()