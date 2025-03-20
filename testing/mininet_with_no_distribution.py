from mininet.net import Mininet
from mininet.node import Controller, OVSSwitch
from mininet.cli import CLI
from mininet.log import setLogLevel
import time

def test_network():
    net = Mininet(controller=Controller, switch=OVSSwitch)
    net.addController('c0')

    switch = net.addSwitch('s1')
    dana = net.addHost('dana', ip='10.5.0.2/16', cpu=1)
    locust = net.addHost('locust', ip='10.5.0.7/16')

    switch2 = net.addSwitch('s2')
    serial = net.addHost('serial', ip='10.6.0.2/16', cpu=1)
    locusts = net.addHost('locusts', ip='10.6.0.3/16')

    net.addLink(dana, switch, delay="1ms")
    net.addLink(locust, switch, delay="5ms")

    net.addLink(serial, switch2, delay="5ms")
    net.addLink(locusts, switch2, delay="20ms")

    net.start()

    # Inicie os serviços com logs
    print("Iniciando serviços...")
    dana.cmd('export DANA_HOME=/home/arthurb/dana_lang && export PATH=$PATH:$DANA_HOME')
    dana.cmd('dana main.o 3 > dana.log 2>&1 &')

    serial.cmd("flask --app serial_matmul/app run --host 0.0.0.0 --port 5000 &")

    # Aguarde 10 segundos para serviços inicializarem
    time.sleep(5)

    # Teste a conectividade
    print("Testando ping entre componentes:")
    net.ping([locust, dana], timeout=1)
    net.ping([locusts, serial], timeout=1)

    # Execute o Locust
    print("Iniciando teste Locust...")
    locust.cmd("locust -f testing/locustfile.py --headless -u 20 -r 4 -H http://10.5.0.2:8080 --run-time 1m --csv results/20/no_distribution/dana &")
    locusts.cmd("locust -f testing/locustfile_serial.py --headless -u 20 -r 4 -H http://10.6.0.2:5000 --run-time 1m --csv results/20/no_distribution/serial &")

    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_network()