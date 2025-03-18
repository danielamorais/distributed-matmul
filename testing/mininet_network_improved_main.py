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
    remote1 = net.addHost('remote1', ip='10.5.0.3/16', cpu=2)
    remote2 = net.addHost('remote2', ip='10.5.0.4/16', cpu=2)
    remote3 = net.addHost('remote3', ip='10.5.0.5/16', cpu=2)
    remote4 = net.addHost('remote4', ip='10.5.0.6/16', cpu=2)
    locust = net.addHost('locust', ip='10.5.0.7/16')

    switch2 = net.addSwitch('s2')
    serial = net.addHost('serial', ip='10.6.0.2/16', cpu=2)
    locusts = net.addHost('locusts', ip='10.6.0.3/16')

    net.addLink(dana, switch, delay="1ms")
    net.addLink(remote1, switch, delay="1ms")
    net.addLink(remote2, switch, delay="1ms")
    net.addLink(remote3, switch, delay="1ms")
    net.addLink(remote4, switch, delay="1ms")
    net.addLink(locust, switch, delay="5ms")

    net.addLink(serial, switch2, delay="5ms")
    net.addLink(locusts, switch2, delay="20ms")

    net.start()

    # Inicie os serviços com logs
    print("Iniciando serviços...")
    dana.cmd('export DANA_HOME=/home/arthurb/dana_lang && export PATH=$PATH:$DANA_HOME')
    remote1.cmd('export DANA_HOME=/home/arthurb/dana_lang && export PATH=$PATH:$DANA_HOME')
    remote2.cmd('export DANA_HOME=/home/arthurb/dana_lang && export PATH=$PATH:$DANA_HOME')
    remote3.cmd('export DANA_HOME=/home/arthurb/dana_lang && export PATH=$PATH:$DANA_HOME')
    remote4.cmd('export DANA_HOME=/home/arthurb/dana_lang && export PATH=$PATH:$DANA_HOME')

    dana.cmd('dana main.o 1 > dana.log 2>&1 &')
    remote1.cmd('dana RemoteRepo.o 8081 2010 > remote1.log 2>&1 &')
    remote2.cmd('dana RemoteRepo.o 8082 2011 > remote2.log 2>&1 &')
    remote3.cmd('dana RemoteRepo.o 8083 2012 > remote3.log 2>&1 &')
    remote4.cmd('dana RemoteRepo.o 8084 2013 > remote4.log 2>&1 &')

    serial.cmd("gunicorn -w 4 -b 0.0.0.0:8000 serial_matmul.app:app &")

    # Aguarde 10 segundos para serviços inicializarem
    time.sleep(5)

    # Teste a conectividade
    print("Testando ping entre componentes:")
    net.ping([dana, remote1], timeout=1)
    net.ping([dana, remote2], timeout=1)
    net.ping([dana, remote3], timeout=1)
    net.ping([dana, remote4], timeout=1)
    net.ping([locust, dana], timeout=1)
    net.ping([locusts, serial], timeout=1)

    # Execute o Locust
    print("Iniciando teste Locust...")
    locust.cmd("locust -f testing/locustfile.py --headless -u 300 -r 50 -H http://10.5.0.2:8080 --run-time 2m --csv results/300r/2cpu/dana &")
    locusts.cmd("locust -f testing/locustfile_serial.py --headless -u 300 -r 50 -H http://10.6.0.2:8000 --run-time 2m --csv results/300r/2cpu/serial &")

    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    test_network()