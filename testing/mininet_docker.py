import logging
from mininet.net import Containernet
from mininet.node import Docker, Controller
from mininet.cli import CLI
from mininet.link import TCLink

# Configuração básica do logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def create_network():
    net = Containernet(controller=Controller, link=TCLink)

    # Controlador
    c0 = net.addController('c0', ip='127.0.0.1', port=6653)

    # Hosts Docker (nomes curtos)
    dana_main = net.addDocker('dana-main', ip='10.0.0.2', dimage="distributed-matmul-dana-main")
    remote1 = net.addDocker('remote1', ip='10.0.0.3', dimage="distributed-matmul-dana-remote-1")
    remote2 = net.addDocker('remote2', ip='10.0.0.4', dimage="distributed-matmul-dana-remote-2")
    # locust = net.addHost('locust', cls=Docker, ip='10.0.0.5', dimage="distributed-matmul-locust-test")
    # serial = net.addHost('serial', cls=Docker, ip='10.0.0.6', dimage="distributed-matmul-serial-matmul")
    # locust_serial = net.addHost('locust-ser', cls=Docker, ip='10.0.0.7', dimage="distributed-matmul-locust-test-serial")

    # Switches
    s1 = net.addSwitch('s1')
    # s2 = net.addSwitch('s2')

    # Links (ajustados para os novos nomes)
    net.addLink(dana_main, s1, delay='1ms', loss=1, r2q=500)
    net.addLink(remote1, s1, delay='1ms', loss=2, r2q=500)
    net.addLink(remote2, s1, delay='1ms', loss=2, r2q=500)
    # net.addLink(locust, s1, bw=15, delay='2ms', loss=0.5, r2q=500)
    # net.addLink(serial, s2, bw=20, delay='20ms', loss=0.1, r2q=500)
    # net.addLink(locust_serial, s2, bw=15, delay='2ms', loss=0.5, r2q=500)

    try:
        net.start()
        logging.info("Rede iniciada com sucesso!")
        
        # Teste de conectividade entre todos os hosts
        logging.info("Executando teste de conectividade (pingAll)")
        net.pingAll()

        # Inicia a CLI para interação
        CLI(net)
    except Exception as e:
        logging.error(f"Ocorreu um erro durante a execução da rede: {e}")
    finally:
        net.stop()
        logging.info("Rede finalizada com segurança.")

if __name__ == '__main__':
    create_network()