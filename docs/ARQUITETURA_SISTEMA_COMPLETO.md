# Arquitetura do Sistema Completo de Multiplicação de Matrizes Distribuída

Este documento descreve a implementação completa do sistema de multiplicação de matrizes distribuída, incluindo a arquitetura atual e os problemas encontrados durante o desenvolvimento.

## Visão Geral do Sistema

O sistema implementado é uma aplicação de multiplicação de matrizes distribuída que utiliza a linguagem de programação Dana. A arquitetura foi projetada para separar claramente as responsabilidades entre componentes que executam em diferentes ambientes: aplicações principais e workers executam em WebAssembly (WASM) dentro de navegadores web, enquanto o servidor coordenador executa nativamente em Dana.

A multiplicação de matrizes é o problema computacional central do sistema. Quando um usuário submete duas matrizes para multiplicação, o sistema distribui o trabalho entre múltiplos workers que executam em diferentes abas do navegador, permitindo processamento paralelo e escalável. O coordenador gerencia a fila de tarefas, atribui trabalho aos workers disponíveis e armazena os resultados até que sejam recuperados pela aplicação principal.

## Arquitetura Atual

### Componentes em WebAssembly

A aplicação principal e os workers foram implementados para executar em WebAssembly dentro de navegadores web. Esta escolha arquitetural permite que o sistema seja executado em qualquer navegador moderno sem necessidade de instalação de software adicional, além de aproveitar os recursos computacionais dos clientes para processamento distribuído.

A aplicação principal (MainApp) é implementada no arquivo `app/main.dn` e utiliza o componente `MainAppLoopImpl` que implementa a interface `MainAppLoop`, que por sua vez estende `lang.ProcessLoop`. Este padrão é essencial para aplicações WASM em Dana, pois o método `main()` não pode bloquear e deve retornar rapidamente para manter o navegador responsivo. O ProcessLoop permite que a aplicação execute continuamente através de chamadas repetidas à função `loop()`, que deve retornar rapidamente sem operações bloqueantes.

A interface do usuário é construída usando o framework de UI do Dana, incluindo componentes como `ui.Window`, `ui.TextArea`, `ui.Button` e `ui.Label`. Quando o usuário insere duas matrizes e clica no botão de submissão, a aplicação constrói uma requisição HTTP POST para o endpoint `/task` do coordenador, enviando as matrizes no formato JSON. Após receber um `taskId` como resposta, a aplicação entra em um estado de polling, fazendo requisições HTTP GET periódicas para o endpoint `/result/:id` até que o resultado esteja disponível.

Os workers são implementados no arquivo `app/BrowserWorkerLoopImpl.dn` e seguem um padrão similar ao da aplicação principal, utilizando `BrowserWorkerLoop` que também estende `lang.ProcessLoop`. Cada worker executa em uma aba separada do navegador e funciona de forma completamente independente. O worker inicia um loop de polling que verifica periodicamente o coordenador para novas tarefas através do endpoint `/task/next`. Quando uma tarefa está disponível, o worker recebe as matrizes A e B, realiza a multiplicação usando o componente `matmul.Matmul`, e então submete o resultado de volta ao coordenador através do endpoint `/task/:id/result`.

A multiplicação de matrizes em si é implementada no componente `matmul.Matmul`, que fornece funções para converter strings JSON em estruturas de dados `Matrix`, realizar a multiplicação, e converter o resultado de volta para string JSON. Este componente é puro código Dana e não depende de bibliotecas externas ou JavaScript, garantindo que todo o processamento computacional aconteça dentro do runtime Dana.

### Servidor Coordenador em Dana Nativo

O servidor coordenador é implementado para executar nativamente em Dana, não em WASM. Esta decisão foi tomada porque o coordenador precisa fazer bind em portas TCP e aceitar conexões de rede, funcionalidades que não estão disponíveis em WASM devido às restrições de segurança dos navegadores.

O componente principal do coordenador é `app/CoordinatorApp.dn`, que implementa a interface `App` e serve como ponto de entrada do servidor. Este componente utiliza `RecursiveLoader` para carregar dinamicamente o `CoordinatorController`, que implementa a interface `server.Coordinator` e contém toda a lógica de gerenciamento de tarefas.

O coordenador mantém uma fila de tarefas em memória usando estruturas de dados simples: um array de objetos `Task` e um array de IDs de tarefas pendentes. Cada tarefa possui um ID único, status (pending, processing, completed), os dados das matrizes, o resultado da multiplicação, e metadados como timestamps e worker ID que processou a tarefa.

O servidor HTTP é implementado usando `net.TCPServerSocket` e `net.TCPSocket` do Dana. Quando uma conexão é aceita, uma nova thread assíncrona é criada para processar a requisição HTTP através da função `handleHTTPRequest`. Esta função lê a requisição do socket, utiliza `network.http.HTTPUtil` para fazer parsing da mensagem HTTP, e então roteia a requisição através do `CoordinatorServer` que decide se deve servir um arquivo estático ou passar a requisição para o `Coordinator`.

O `CoordinatorServer` implementa a interface `server.CoordinatorServer` e atua como um roteador HTTP. Ele verifica se a requisição é um OPTIONS (para CORS preflight), verifica se é o endpoint `/health`, tenta servir arquivos estáticos através do `StaticFileServer` se disponível, e finalmente roteia requisições de API para o `Coordinator`. Todas as respostas incluem cabeçalhos CORS apropriados para permitir requisições cross-origin dos navegadores.

O `CoordinatorController` implementa todos os endpoints da API: POST `/task` para submissão de novas tarefas, GET `/task/next` para workers solicitarem a próxima tarefa, POST `/task/:id/result` para workers submeterem resultados, GET `/result/:id` para a aplicação principal recuperar resultados, e GET `/stats` para estatísticas do sistema. Todas as operações que modificam o estado compartilhado são protegidas por mutex para garantir thread-safety.

### Fluxo de Dados

O fluxo completo de uma multiplicação de matrizes funciona da seguinte forma. Primeiro, o usuário abre a aplicação principal em uma aba do navegador, que carrega o runtime Dana WASM e o arquivo `file_system_main.js` que contém todos os componentes compilados empacotados. A aplicação inicializa a interface do usuário e aguarda entrada do usuário.

Quando o usuário submete duas matrizes, a aplicação principal constrói uma requisição HTTP POST para `http://localhost:8080/task` com um corpo JSON contendo as matrizes A e B. Esta requisição é feita de forma assíncrona usando `asynch::executeSubmitRequest`, pois requisições HTTP em WASM devem ser executadas em contexto assíncrono, não diretamente no `loop()` do ProcessLoop.

O coordenador recebe a requisição, cria uma nova tarefa com um ID único, armazena os dados da tarefa em memória, adiciona o ID à fila de tarefas pendentes, e retorna uma resposta JSON com o `taskId`. A aplicação principal recebe esta resposta, armazena o `taskId`, e entra em um estado de polling onde periodicamente faz requisições GET para `/result/:id` até que o resultado esteja disponível.

Enquanto isso, um ou mais workers executando em abas separadas do navegador estão fazendo polling no endpoint `/task/next`. Quando um worker faz uma requisição e há uma tarefa pendente na fila, o coordenador remove a tarefa da fila, marca seu status como "processing", atribui o worker ID à tarefa, e retorna os dados das matrizes A e B.

O worker recebe a tarefa, converte as strings JSON em estruturas `Matrix` usando `matmul.charToMatrix`, realiza a multiplicação usando `matmul.multiply`, converte o resultado de volta para string JSON usando `matmul.matrixToChar`, e então submete o resultado ao coordenador através de uma requisição POST para `/task/:id/result`.

O coordenador recebe o resultado, atualiza o status da tarefa para "completed", armazena o resultado, e retorna uma confirmação. Quando a aplicação principal faz seu próximo poll no endpoint `/result/:id`, o coordenador retorna o resultado completo, e a aplicação principal exibe o resultado na interface do usuário.

## Problemas Encontrados e Soluções

Durante o desenvolvimento do sistema, vários problemas significativos foram encontrados e resolvidos. Estes problemas estão documentados aqui para referência futura e para ajudar outros desenvolvedores que possam enfrentar desafios similares.

Um dos primeiros problemas encontrados foi relacionado ao carregamento de componentes em Dana. O sistema inicialmente tentou usar auto-instantiação para o `CoordinatorController`, mas descobriu-se que componentes que precisam ser carregados dinamicamente devem ser explicitamente carregados usando `RecursiveLoader`. O erro manifestava-se como endpoints HTTP que simplesmente travavam sem retornar resposta, porque o objeto `coordinator` estava null. A solução foi modificar `CoordinatorApp.dn` para usar `RecursiveLoader` explicitamente para carregar o `CoordinatorController`, verificando se o carregamento foi bem-sucedido antes de tentar instanciar o objeto.

Outro problema crítico foi relacionado ao nome de arquivos de componentes. Dana possui uma convenção rigorosa onde o nome do arquivo do componente deve corresponder exatamente ao nome da interface que ele fornece. Quando o componente foi nomeado `MainAppLoopImpl.dn` mas fornecia a interface `MainAppLoop`, o sistema de auto-linking do Dana não conseguia encontrar o componente, resultando no erro "No default component found to satisfy required interface 'MainAppLoop'". A solução foi renomear o arquivo para corresponder exatamente ao nome da interface, ou mover o componente para o diretório `resources/` seguindo as convenções do Dana.

Um problema particularmente desafiador foi o gerenciamento de operações bloqueantes em ProcessLoops. Inicialmente, o código tentou usar `timer.sleep()` dentro do método `handlePollResponse()` para adicionar um atraso antes de resetar o estado. No entanto, qualquer operação bloqueante dentro do `loop()` do ProcessLoop causa o travamento do navegador, pois o navegador interpreta isso como um script que não retorna controle. A solução foi remover todas as chamadas bloqueantes e usar contadores de loop para implementar atrasos não-bloqueantes, ou mover operações que requerem tempo para funções assíncronas separadas.

A questão de requisições HTTP em WASM também apresentou desafios. Descobriu-se que `net.http.HTTPRequest` não pode ser usado diretamente dentro do método `loop()` do ProcessLoop em WASM. Todas as requisições HTTP devem ser executadas em contexto assíncrono usando `asynch::`. O padrão implementado foi criar funções separadas como `executeSubmitRequest` e `executePollRequest` que são chamadas com `asynch::`, e então usar flags de estado como `waitingForResponse` para verificar no `loop()` quando a resposta está disponível.

Um problema relacionado a buffers de socket TCP foi encontrado no coordenador. Quando o coordenador enviava respostas HTTP, às vezes os dados não eram completamente transmitidos antes que a conexão fosse fechada, resultando em respostas truncadas ou vazias para os clientes. O problema estava relacionado ao fato de que `TCPSocket.send()` em modo bloqueante retorna após escrever no buffer do sistema operacional, mas o sistema operacional pode não ter transmitido os dados pela rede ainda. Quando `disconnect()` é chamado imediatamente após `send()`, o sistema operacional pode descartar dados ainda não transmitidos. A solução implementada foi adicionar uma função `flushSocket()` que verifica se há bytes não enviados no buffer do Dana usando `getBufferUnsent()` e `sendBuffer()`, e então adiciona um atraso artificial para dar tempo ao sistema operacional de transmitir os dados. Embora esta seja uma solução de contorno, ela resolve o problema de forma confiável.

A serialização e parsing de JSON também apresentou desafios. O sistema precisa converter entre strings JSON e estruturas de dados Dana em múltiplos pontos: quando a aplicação principal envia matrizes, quando o coordenador armazena tarefas, quando workers recebem tarefas, e quando resultados são retornados. Inicialmente, havia inconsistências em como os dados JSON eram estruturados, com alguns lugares esperando objetos aninhados e outros esperando strings simples. A solução foi padronizar o formato: matrizes são sempre enviadas como strings JSON (por exemplo, "[[1,2],[3,4]]"), e o sistema usa `data.json.JSONEncoder` e `data.json.JSONParser` consistentemente em todos os pontos de conversão.

Um problema relacionado à compilação para WASM foi descoberto. Componentes devem ser compilados com flags específicas para WASM: `-os ubc -chip 32`. Além disso, os componentes compilados devem ser empacotados em um arquivo `file_system.js` usando a ferramenta `file_packager` do Emscripten. Inicialmente, o sistema tentou usar os mesmos arquivos `.o` compilados para execução nativa, mas descobriu-se que arquivos WASM precisam ser empacotados de forma especial. A solução foi criar scripts separados `compile-main-wasm.sh` e `package-main-wasm.sh` para a aplicação principal, e `compile-worker-wasm.sh` e `package-worker-wasm.sh` para os workers, cada um gerando seu próprio `file_system.js` que é referenciado no HTML correspondente.

A questão de múltiplos file systems também foi um desafio. Como a aplicação principal e os workers são aplicações WASM separadas que executam em abas diferentes, cada uma precisa de seu próprio `file_system.js` empacotado. Inicialmente, o sistema tentou usar um único arquivo, mas isso causava conflitos. A solução foi gerar `file_system_main.js` para a aplicação principal e `file_system_worker.js` para os workers, e configurar cada arquivo HTML para carregar o file system apropriado.

Um problema sutil foi encontrado relacionado à geração de worker IDs. O worker inicialmente tentava gerar seu ID usando `loopCount` no construtor, mas `loopCount` ainda era zero nesse ponto. A solução foi gerar o ID de forma diferente, usando um contador estático ou um identificador baseado em timestamp, ou simplesmente usar um prefixo fixo com um sufixo aleatório.

Finalmente, um problema de race condition foi descoberto no coordenador quando múltiplos workers faziam polling simultaneamente. Embora o código usasse mutex para proteger operações na fila de tarefas, havia uma janela onde dois workers poderiam receber a mesma tarefa se ambos fizessem a requisição antes que o primeiro atualizasse o status. A solução foi garantir que a remoção da fila e a atualização do status aconteçam atomicamente dentro do mesmo bloco mutex, e verificar o status da tarefa antes de atribuí-la a um worker.

## Considerações de Design

A arquitetura do sistema foi projetada com várias considerações importantes em mente. A separação entre componentes WASM e componentes nativos permite que o sistema aproveite as vantagens de cada ambiente: WASM para interface do usuário e processamento distribuído no cliente, e código nativo para o servidor que precisa de acesso completo à rede.

O uso de ProcessLoops em vez de loops bloqueantes é essencial para aplicações WASM, pois mantém o navegador responsivo. O padrão de estado assíncrono com flags como `waitingForResponse` permite que o sistema gerencie operações de I/O sem bloquear o thread principal.

A escolha de usar HTTP em vez de TCP direto para comunicação entre componentes WASM e o coordenador é necessária devido às restrições de segurança dos navegadores. Embora isso adicione overhead de protocolo, é a única forma viável de comunicação de rede em WASM.

O sistema de fila de tarefas em memória é adequado para um proof-of-concept, mas em um sistema de produção seria necessário persistência em banco de dados e mecanismos de recuperação de falhas. Da mesma forma, o sistema atual não implementa timeouts para tarefas ou workers que param de responder, o que seria necessário em um ambiente de produção.

A arquitetura permite escalabilidade horizontal adicionando mais workers simplesmente abrindo mais abas do navegador, mas o coordenador atual é um ponto único de falha. Em um sistema de produção, seria necessário implementar redundância e balanceamento de carga para o coordenador.

## Conclusão

O sistema implementado demonstra uma arquitetura funcional de multiplicação de matrizes distribuída usando Dana, com componentes principais e workers executando em WASM e um coordenador executando nativamente. A implementação resolveu vários desafios técnicos relacionados a WASM, ProcessLoops, comunicação HTTP, e gerenciamento de estado compartilhado. Embora o sistema atual seja adequado para demonstração e pesquisa, várias melhorias seriam necessárias para um ambiente de produção, incluindo persistência, recuperação de falhas, e escalabilidade do coordenador.

