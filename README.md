# Do ZERO ao Cluster em Casa com Kubernetes

---
## O que iremos utilizar?
| Ferramentas |                                                                    Links                                                                     |
| :---------: | :------------------------------------------------------------------------------------------------------------------------------------------: |
|   DietPi    |      [![DietPi](https://img.shields.io/badge/DietPi-000000?style=for-the-badge&logo=raspberry-pi&logoColor=white)](https://dietpi.com/)      |
|     K3S     |            [![K3S](https://img.shields.io/badge/K3S-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://k3s.io/)            |
|   Ansible   |       [![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white)](https://ansible.com/)       |
|     Git     |             [![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)](https://git-scm.com/)             |
|     ssh     |           [![ssh](https://img.shields.io/badge/ssh-000000?style=for-the-badge&logo=ssh&logoColor=white)](https://www.ssh.com/ssh/)           |
|    Bash     |  [![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)   |
| Cloudflare  | [![Cloudflare](https://img.shields.io/badge/Cloudflare-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)](https://cloudflare.com/) |
|   Metallb   | [![Metallb](https://img.shields.io/badge/Metallb-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://metallb.universe.tf/)  |
|    Lens     |           [![Lens](https://img.shields.io/badge/Lens-326CE5?style=for-the-badge&logo=lens&logoColor=white)](https://k8slens.dev/)            |

# Preparando o ambiente
## Considerações
Não irei abordar:
- A instalação do DietPi profundamente, pois é bem simples e intuitivo, espera-se que você já tenha conhecimento básico de Linux. É possível utilizar outra distribuição Linux como Ubuntu, Debian, etc, porém, pode haver necessidade de adaptações de alguns passos.

O ambiente que estarei utilizando como referencia:
- 2x Raspberry Pi 4B 4GB RAM
- 1x Mini PC 8GB RAM 4 Cores
- 1x Switch 5 Portas
- 1x Roteador
- 1x Computador auxiliar

Schema
![Kubernetes](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/hardwares.schema.png)

---
## 1. Passo - Instalação do DietPi
### DietPi
Para cada Raspberry Pi(RP4) e o MINI PC, instale o DietPi configurando:
  - leia com atenção as opções de instalação e instale o mínimo possível, pois iremos utilizar o mínimo de recursos possíveis.
  - Configure as interfaces de rede para um IP estático
  - Configure o usuário e senha, e salve em um local seguro(iremos utilizar para acessar o servidor posteriormente)
  - lembre-se de anotar o IP de cada servidor, pois iremos utilizar para acessar o servidor posteriormente

---
## 2. Passo - Configuração do Ansible
No computador **auxiliar**, instale o Ansible e Git
```bash
# Instalando o Ansible
pip install ansible
```

---
## 3. Passo - Criando Hosts do Ansible para instalação do K3s
Criando a configuração dos hosts do Ansible:
Considere que os endereços dos hosts são: 

1. - RP4: 192.168.3.102
2. - RP4: 192.168.3.100
3. - MINI PC: 192.168.3.101
> **OBS: Atualize o arquivo hosts.yaml com os endereços dos seus servidores e seus respectivos usuários e senhas.**
```yaml
# hosts.yaml
MASTER:
  hosts:
    rp4:
      ansible_host: 192.168.3.102
      ansible_user: root
      ansible_ssh_pass: dietpi
      ansible_become: yes

NODES:
  hosts:
    rp4:
      ansible_host: 192.168.3.100
      ansible_user: root
      ansible_ssh_pass: dietpi
      ansible_become: yes

    minipc:
      ansible_host: 192.168.3.101
      ansible_user: root
      ansible_ssh_pass: dietpi
      ansible_become: yes

SERVERS:
  children:
    MASTER:
    NODES:

```
> Aqui configuramos 1 MASTER e 2 NODES, podendo variar de acordo com a sua necessidade. 

---
## 4. Passo - Configuração do Playbook do Ansible para instalação do K3S 
No computador auxiliar criaremos o seguinte playbook de instalação do K3S:
```yaml
# k3s.install.yaml
- name: Instalando K3S no MASTER
  hosts: MASTER
  vars:
    MASTER_HOST: '192.168.3.102'
  tasks:
    - name: -> MASTER - Instalando o K3S
      shell: |
        curl -sfL https://get.k3s.io | sh -s - \
        --write-kubeconfig-mode 644 \ 
        --disable servicelb,traefik,metrics-server \ 
        --token master-password \
        --node-taint CriticalAddonsOnly=true:NoExecute \
        --bind-address "{{ MASTER_HOST }}" \
        --node-name MASTER
      register: k3s_install
      ignore_errors: no

    - name: -> MASTER - Acessar o arquivo de configuração do K3S
      shell: cat /etc/rancher/k3s/k3s.yaml
      register: k3s_cfg
      ignore_errors: no

    - name: -> MASTER - Copiar o arquivo de configuração do K3S
      delegate_to: localhost
      copy:
        content: "{{ k3s_cfg.stdout }}" 
        dest: "{{ playbook_dir }}/k3s.cfg.yaml"
      ignore_errors: no
    
- name: NODES - Instalando K3S nos NODES
  hosts: NODES
  vars:
    MASTER_HOST: '192.168.3.102'
  tasks:
    - name: -> NODE - INSTALL K3S
      shell: |
        curl -sfL https://get.k3s.io | \
        K3S_URL="https://{{ MASTER_HOST }}:6443" \
        K3S_TOKEN=master-password \
        K3S_NODE_NAME=NODE-{{inventory_hostname.upper()}} \
        sh -
```
> Após a criação do playbook, execute o comando abaixo para instalar o K3S nos servidores:
> ```bash
> # Executando o playbook
> ansible-playbook -i hosts.yaml k3s.install.yaml
> ```

![Install](https://github.com/nicolasmmb/the-kubernetes/blob/master/assets/k3s/k3s.install.gif?raw=true)

- **Esse processo pode demorar alguns minutos, pois o K3S irá baixar os binários e instalar os componentes necessários em todos os servidores.**

- **OBS: Caso haja algum erro, relacionado a conexão ssh, verifique se o usuário e senha estão corretos e tente exportar `export ANSIBLE_HOST_KEY_CHECKING=False` antes de executar o playbook.**

---
## 5. Passo - Reiniciando os servidores
Após a instalação do K3S, reinicie os servidores para que o K3S possa iniciar os serviços corretamente validar se os serviços estão iniciando corretamente.
```yaml
# reboot.yaml
- name: REBOOT ALL
  hosts: SERVERS
  tasks:
    - name: -> REBOOT
      shell: |
        reboot now
      become: yes
      become_user: root
      register: reboot
      ignore_errors: no
```
Após a criação do playbook, execute o comando abaixo para reiniciar os servidores:
```bash
# Executando o playbook
ansible-playbook -i hosts.yaml reboot.yaml
```

---
## 6. Passo - Validando a instalação do K3S
Após a reinicialização dos servidores, verifique se os serviços do K3S estão iniciando corretamente.
Verifique se os nodes estão com o status Ready, com o comando abaixo:
```bash
# exportando env do arquivo de configuração do K3S gerado pelo playbook - temporário
export KUBECONFIG=$PWD/k3s.cfg.yaml

# verificando os nodes
kubectl get nodes
```
![Validando](https://github.com/nicolasmmb/the-kubernetes/blob/master/assets/k3s/k3s.validando.gif?raw=true)
> **OBS: Caso os nodes não estejam com o status Ready, verifique os logs do K3S para identificar o problema ou se ainda estão iniciando.**

## 7. Passo - Adicionando o comando k3s no bashrc ou zshrc
Para facilitar o uso do kubectl, iremos adicionar um alias no ***bashrc*** ou ***zshrc*** para que não seja necessário exportar o **KUBECONFIG** toda vez que for executar um comando.
*Caso utilize **ZSH**, altere os comandos abaixo de `~/.bashrc` para `~/.zshrc`*
```bash
echo "alias k3s='"KUBECONFIG=$PWD/k3s.cfg.yaml kubectl --context=default"'" >> ~/.bashrc
```
Após adicionar o alias, execute o comando abaixo para carregar o arquivo de configuração do ***bashrc*** ou ***zshrc***
```bash
source ~/.bashrc
```
![Alias](https://github.com/nicolasmmb/the-kubernetes/blob/master/assets/k3s/k3s.alias.gif?raw=true)


## 8. Passo - `Opcional` Removendo o K3S
```bash
ansible-playbook -i hosts.yaml k3s.uninstall.yaml
```
![Uninstall](https://github.com/nicolasmmb/the-kubernetes/blob/master/assets/k3s/k3s.uninstall.gif?raw=true)

---
# Ajustes Pós Instalação
## 1. Passo - Configurando o MetalLB
Para que serve o MetalLB?
O MetalLB é um LoadBalancer para ambientes bare-metal, ou seja, não é necessário utilizar um serviço de cloud para provisionar um LoadBalancer, o MetalLB irá utilizar o protocolo ARP para anunciar o IP do LoadBalancer para a rede local.


### 1.1 MetalLB - Instalação
Para instalar o MetalLB, execute o comando abaixo:
```bash
k3s apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
```
![Install](https://github.com/nicolasmmb/the-kubernetes/blob/master/assets/metallb/metallb.install.gif?raw=true)
### 1.2 MetalLB - Criando o secret para o memberlist
```bash
k3s create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```
![Create](https://github.com/nicolasmmb/the-kubernetes/blob/master/assets/metallb/metallb.memberlist.secret.gif?raw=true)

### 1.3 MetalLB - Criando o IP Pool
Será criado um IP Pool com o range de IPs de 200 a 220, ou seja, o MetalLB irá utilizar os IPs de 200 a 220 para provisionar os LoadBalancers.

Abaixo um exemplo de IP Pool:
```yaml
# metallb.IPAddressPools.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ip-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.3.200-192.168.3.220
```

Aplicando o IP Pool.
```bash
k3s apply -f metallb.IPAddressPools.yaml
```
![IPPool](https://github.com/nicolasmmb/the-kubernetes/blob/master/assets/metallb/metallb.ippool.gif?raw=true)


### 1.5 MetalLB - Criando o Anúncio da Camada L2
No modo da camada 2, um ***NODE*** assume a responsabilidade de anunciar um serviço para a rede local. Do ponto de vista da rede, simplesmente parece que aquela máquina tem vários endereços IP atribuídos à sua interface de rede.
```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: ips-pool-advertisement
  namespace: metallb-system
```

Aplicando o Anuncio da Camada L2.
```bash
k3s apply -f metallb.L2Advertisement.yaml
```
![L2Advertisement](https://github.com/nicolasmmb/the-kubernetes/blob/master/assets/metallb/metallb.l2advertisement.gif?raw=true)


### 1.6 MetalLB - Validando a instalação
Para validar a instalação do MetalLB, execute o comando abaixo:
```bash
k3s get pods -n metallb-system
```
Os pods do MetalLB devem estar com o status Running.


---
## 2. Passo - Configurando o Lens
Para que serve o Lens?
O Lens é uma ferramenta para gerenciamento de clusters Kubernetes, que permite a visualização de todos os recursos do cluster, além de permitir a execução de comandos e a criação de recursos.

### 2.1 Lens - Instalação
Para instalar o Lens, acesso o site https://k8slens.dev/ e baixe a versão para o seu sistema operacional.

### 2.2 Lens - Configuração
#### 2.2.1 Iniciando o Lens
![Lens](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/lens/01.png)

#### 2.2.2 Acessando o Catalog
![Lens](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/lens/02.png)

#### 2.2.3 Adicionando o Cluster
![Lens](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/lens/03.png)

#### 2.2.4 Selecionando o tipo do arquivo de configuração
![Lens](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/lens/04.png)

#### 2.2.5 Adicionando a Configuração do Cluster
Adicione o arquivo de configuração do K3S gerado pelo playbook.
![Lens](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/lens/05.png)

#### 2.2.6 Validando a conexão com o Cluster
![Lens](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/lens/06.png)

#### 2.2.7 Acessando os recursos do Cluster
![Lens](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/lens/07.png)

## 3 Configurando o Metrics Server
Para que serve o Metrics Server?
Basicamente ele coleta métricas de recursos em execução em cada nó e agrega essas métricas e disponibiliza para consulta.

### 3.1 Metrics Server - Instalação
Para instalar o Metrics Server integrado com o Lens, siga os passos abaixo:

#### 3.1.1 Acesse o menu `Catalog`
![Metrics Server](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/metrics-server/01.png)

#### 3.1.2 Acesse as configurações do Cluster
![Metrics Server](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/metrics-server/02.png)

#### 3.1.3 Acesse o menu `Builtin Metrics Provider`
![Metrics Server](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/metrics-server/03.png)

#### 3.1.4 Ative as opções `Enable...` e aplique com `Apply`
![Metrics Server](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/metrics-server/04.png)

#### 3.1.5 Acesse o menu do Cluster e verifique as métricas
![Metrics Server](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/metrics-server/05.png)
---


## 4. Primeiro Deploy no Kubernetes
Iremos testar se tudo está funcionando, K3s, MetalLB...

> Iremos utilizar o Uptime Kuma, que é uma ferramenta para monitoramento de serviços, que permite a criação de dashboards para visualização dos serviços.

### 4.1 Uptime Kuma - Namespace
**O que é um namespace?**
Um namespace é um recurso do Kubernetes que permite a separação de recursos em um cluster, permitindo a organização e separação de recursos.
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: uptime-kuma
```

Aplicando o namespace.
```bash
k3s apply -f kuma.namespace.yaml
```

### 4.2 Uptime Kuma - Deployment
**O que é um deployment?**
O `deployment` no Kubernetes é um objeto que gerencia a implantação de uma aplicação em um cluster. Ele garante que o estado esperado da aplicação seja mantido, definindo configurações como o número de réplicas, imagem do container, atualizações e rollbacks. Quando um deployment é criado, ele cria automaticamente um conjunto replicado de pods que executam a aplicação, garantindo a disponibilidade do serviço.
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: uptime-kuma
  namespace: uptime-kuma
spec:
  replicas: 1
  selector:
    matchLabels:
      app: uptime-kuma
  template:
    metadata:
      labels:
        app: uptime-kuma
    spec:
      containers:
        - name: uptime-kuma
          image: louislam/uptime-kuma:1
          ports:
            - containerPort: 3001
              hostPort: 3001
              protocol: TCP
          resources:
            limits:
              memory: "128Mi"
              cpu: "500m"
            requests:
              memory: "64Mi"
              cpu: "250m"
```

Aplicando o deployment.
```bash
k3s apply -f kuma.deployment.yaml
```

### 4.3 Uptime Kuma - Service
**O que é um service?**
um `service` no Kubernetes é um objeto que define uma política de acesso aos pods de um deployment ou de um conjunto de pods.
Ele permite que os pods sejam acessados por outros componentes dentro ou fora do cluster, independentemente de suas localizações específicas. O service também garante que o tráfego seja roteado adequadamente para os pods correspondentes, mesmo que os mesmos sejam adicionados ou removidos do cluster.
```yaml
apiVersion: v1
kind: Service
metadata:
  name: uptime-svc
  namespace: uptime-kuma
spec:
  selector:
    app: uptime-kuma
  ports:
    - name: http
      port: 3001
      protocol: TCP
      targetPort: 3001
  type: LoadBalancer
  loadBalancerIP: 192.168.3.205
```

Aplicando o service.
```bash
k3s apply -f kuma.service.yaml
```

### 4.4 Uptime Kuma - Validando o Deploy
Para validar o deploy, execute o comando abaixo:
```bash
k3s get pods -n uptime-kuma
```

Deve ter um pod com o nome uptime-kuma-xxxxx com o status Running.

### 4.5 Uptime Kuma - Acessando o serviço
Para acessar o serviço, acesse o endereço http://192.168.3.205:3001
![Uptime Kuma](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/uptimekuma/kuma.png)

E temos como resultado o Uptime Kuma funcionando.


---
## 5. Passo - Configurando o Cloudflare
Para que iremos utilizar o Cloudflare?
- Caso sua provedora de internet não libere o IP público(como a minha), será necessário utilizar um serviço de *Tunneling*, para que seja possível acessar os serviços do cluster Kubernetes através de um domínio.

### 5.1 Cloudflare - Faça o Login
Acesse o site https://dash.cloudflare.com/login e faça o login com a sua conta. Caso não tenha uma conta, crie uma conta gratuita.

### 5.2 Cloudflare - Compre um domínio ou configure um domínio existente
Valide se você possui um domínio, caso não tenha um domínio, compre um domínio ou configure um domínio existente no Cloudflare.

- Devemos ter um domínio configurado no Cloudflare, como na imagem abaixo:
 
![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/01.png) 


### 5.3 Cloudflare - Criando o Tunnel
#### 5.3.1 Acesse o menu `Zero Trust`
![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/02.png)
![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/03.png)

#### 5.3.2 Acesse o menu `Access > Tunnels`
![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/04.png)
![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/05.png)


#### 5.3.3 Clique em `Create Tunnel`
- Preencha o nome do Tunnel e clique em `Next`

![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/06.png)
![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/07.png)

#### 5.3.4 Configure o Tunnel
- Salve o Token em algum lugar, posteriormente iremos utilizar.
- Clique em `Next`

![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/08.png)
![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/09.png)



#### 5.3.5 Configure o Tunnel > `Route tunnel`
- Preencha o `Subdomain` com o nome do seu domínio, no meu caso `kuma`
- Selecione o `Domain` que você configurou no Cloudflare, no meu caso `nikorasu.work`

![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/10.png)

- Preencha o Service:
  - Type: `HTTP`
  - URL: 

![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/11.png)

- Salve clicando em `Save tunnel`
  

#### 5.3.6 Criando um `Deployment` para o Tunnel
```yaml
apiVersion: apps/v1
kind: pod
metadata:
  name: uptime-kuma-tunnel
  namespace: uptime-kuma

spec:
  containers:
    - name: uptime-kuma-tunnel
      image: cloudflare/cloudflared:latest
      imagePullPolicy: Always
      resources:
        requests:
          memory: "128Mi"
          cpu: "96m"
        limits:
          memory: "256Mi"
          cpu: "128m"
      args:
        - "tunnel"
        - "--no-autoupdate"
        - "run"
        - "--token"
        - "<SEU-TOKEN>"
```

- Substitua o `<SEU-TOKEN>` pelo token que você salvou anteriormente.

Aplicando o deployment.
```bash
k3s apply -f kuma.service.tunnel.yaml
```

### 5.4 Cloudflare - Acessando o serviço
Acesse o endereço que você configurou no Cloudflare, no meu caso 
![Cloudflare](https://raw.githubusercontent.com/nicolasmmb/the-kubernetes/a55bbc265b41b765ea9b7eda1dd81bb17b784855/assets/cloudflare/12.png)

E temos como resultado o Uptime Kuma funcionando através do Cloudflare Tunnel, sem a necessidade de abrir portas no roteador e com HTTPS, sendo possível acessar o serviço de qualquer lugar.


## 6. Considerações Finais
Parabéns, você chegou até aqui, agora você tem um cluster Kubernetes rodando em sua casa, com um domínio configurado no Cloudflare e com o Uptime Kuma funcionando através do Cloudflare Tunnel e muito mais.
Já tem a base para fazer o deploy com o Kubernetes, agora é só brincar e aprender mais sobre Kubernetes.

O que você pode fazer agora?
- Fazer o deploy de uma aplicação no cluster Kubernetes.
- Ter seu próprio site, blog, etc.
- Criar um APIs em Python, Go, NodeJS, etc e fazer o deploy no cluster, disponibilizando o acesso externo através do Cloudflare Tunnel.
- Entender como funciona o Ingress Controller e fazer o deploy de uma aplicação com Ingress Controller.
- Entender como funciona o HPAs e fazer o deploy de uma aplicação com HPA. (Horizontal Pod Autoscaler)
- Criar um servidor Local de Minecraft, utilizando o Kubernetes.
- Criar Um Consummer de Filas, como RabbitMQ, utilizando varios Nodes para maior performance.


## 7. Proximos passos
Coisas que eu quero adicionar nesse tutorial.
- [ ] Configurar o Longhorn para armazenamento persistente.
- [ ] Automatizar mais processos da criação do cluster.
- [ ] Adicionar: Como criar sua própria imagem Docker.
- [ ] Adicionar: Como criar um servidor de Minecraft com Kubernetes.
- [ ] Adicionar: Acessando API do Kubernetes com Golang.
- [ ] Devemos usar banco de dados no Kubernetes?


## 8. Referências
Links que me ajudaram a criar esse tutorial.
- https://google.com/
- https://www.youtube.com/
- https://k3s.io
- https://kubernetes.io

### 8.1 Repositório
- https://github.com/nicolasmmb/the-kubernetes
