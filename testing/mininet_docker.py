from mininet.net import Containernet
from mininet.node import Controller
from mininet.cli import CLI
from mininet.link import TCLink
from mininet.log import setLogLevel, output

def create_network():
    net = Containernet(controller=Controller, link=TCLink)
    net.addController('c0', ip='127.0.0.1', port=6653)

    # Hosts Docker (nomes curtos)
    dana_main = net.addDocker('dana',
                              ip='10.0.0.251/24',
                              ports=[8080],
                              port_bindings={8080: 8080},
                              network_mode="none",
                              dimage="distributed-matmul-dana-main")
    remote1 = net.addDocker('remote1',
                            ip='10.0.0.252/24',
                            ports=[8081],
                            port_bindings={8081: 8081},
                            environment={"PORT": 8081, "APP_PORT": 2010},
                            network_mode="none",
                            dimage="distributed-matmul-dana-remote-1")
    remote2 = net.addDocker('remote2',
                            ip='10.0.0.253/24',
                            ports=[8082],
                            port_bindings={8082: 8082},
                            environment={"PORT": 8082, "APP_PORT": 2011},
                            network_mode="none",
                            dimage="distributed-matmul-dana-remote-2")
    locust = net.addDocker('locust',
                           ip='10.0.0.249/24',
                           dimage="distributed-matmul-locust-test",
                           environment={"LOCUST_HEADLESS": "true", "LOCUST_USERS": 500, "LOCUST_SPAWN_RATE": 50, "LOCUST_HOST": "http://10.0.0.251:8080", "LOCUST_RUN_TIME": "1m", "LOCUST_CSV": "results"},
                           network_mode="none",
                           volumes=["/app/distributed-matmul/testing:/home/locust:rw"])
    # serial = net.addHost('serial', cls=Docker, ip='10.0.0.6', dimage="distributed-matmul-serial-matmul")
    # locust_serial = net.addHost('locust-ser', cls=Docker, ip='10.0.0.7', dimage="distributed-matmul-locust-test-serial")

    # Switches
    s1 = net.addSwitch('s1')
    # s2 = net.addSwitch('s2')

    # Links (ajustados para os novos nomes)
    net.addLink(dana_main, s1, delay='1ms')
    net.addLink(remote1, s1, delay='1ms')
    net.addLink(remote2, s1, delay='1ms')
    net.addLink(locust, s1, delay='6ms')
    # net.addLink(serial, s2, bw=20, delay='20ms', loss=0.1, r2q=500)
    # net.addLink(locust_serial, s2, bw=15, delay='2ms', loss=0.5, r2q=500)

    try:
        net.start()
        output("Rede iniciada com sucesso!")
        
        # Teste de conectividade entre todos os hosts
        output("Executando teste de conectividade (pingAll)")
        net.pingAll()

        # Inicia a CLI para interação
        CLI(net)
    except Exception as e:
        output(f"Ocorreu um erro durante a execução da rede: {e}")
    finally:
        net.stop()
        output("Rede finalizada com segurança.")

if __name__ == '__main__':
    setLogLevel('info')
    create_network()