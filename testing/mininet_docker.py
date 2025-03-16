from mininet.net import Containernet
from mininet.node import Docker
from mininet.cli import CLI
from mininet.link import TCLink
from mininet.node import RemoteController

def create_network():
    net = Containernet(controller=RemoteController, link=TCLink)

    # Configuração do controlador (assumindo que está rodando localmente)
    c0 = net.addController('c0', ip='127.0.0.1', port=6653)

    # Criação dos hosts Docker
    dana_main = net.addHost('dana-main', cls=Docker, ip='10.0.0.1', dimage="distributed-matmul-dana-main")
    dana_remote_1 = net.addHost('dana-remote-1', cls=Docker, ip='10.0.0.2', dimage="distributed-matmul-dana-remote-1")
    dana_remote_2 = net.addHost('dana-remote-2', cls=Docker, ip='10.0.0.3', dimage="distributed-matmul-dana-remote-2")
    locust_test = net.addHost('locust-test', cls=Docker, ip='10.0.0.4', dimage="distributed-matmul-locust-test")
    serial_matmul = net.addHost('serial-matmul', cls=Docker, ip='10.0.0.5', dimage="distributed-matmul-serial-matmul")
    locust_test_serial = net.addHost('locust-test-serial', cls=Docker, ip='10.0.0.6', dimage="distributed-matmul-locust-test-serial")

    # Criação dos switches
    s1 = net.addSwitch('s1')
    s2 = net.addSwitch('s2')

    # Conexões com parâmetros de QoS
    net.addLink(dana_main, s1, bw=10, delay='6ms', loss=1)
    net.addLink(dana_remote_1, s1, bw=5, delay='1ms', loss=2)
    net.addLink(dana_remote_2, s1, bw=5, delay='1ms', loss=2)
    net.addLink(locust_test, s1, bw=15, delay='2ms', loss=0.5)
    net.addLink(serial_matmul, s2, bw=20, delay='20ms', loss=0.1)
    net.addLink(locust_test_serial, s2, bw=15, delay='2ms', loss=0.5)
    net.addLink(s1, s2, bw=50, delay='1ms', loss=0.1)

    net.start()

    # Comandos de configuração opcionais
    dana_main.cmd("echo 'Configurando dana-main...'")
    dana_remote_1.cmd("echo 'Configurando dana-remote-1...'")
    dana_remote_2.cmd("echo 'Configurando dana-remote-2...'")
    locust_test.cmd("echo 'Configurando locust-test...'")
    serial_matmul.cmd("echo 'Configurando serial-matmul...'")
    locust_test_serial.cmd("echo 'Configurando locust-test-serial...'")

    CLI(net)
    net.stop()

if __name__ == '__main__':
    create_network()