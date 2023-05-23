# Do ZERO o Servidor em Casa com Kubernetes

---
## O que iremos utilizar?
| Ferramentas |                                                                    Links                                                                     |
| :---------: | :------------------------------------------------------------------------------------------------------------------------------------------: |
|   DietPi    |      [![DietPi](https://img.shields.io/badge/DietPi-000000?style=for-the-badge&logo=raspberry-pi&logoColor=white)](https://dietpi.com/)      |
|     K3S     |            [![K3S](https://img.shields.io/badge/K3S-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://k3s.io/)            |
|   Docker    |         [![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com/)         |
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
![Kubernetes](/assets/hardwares.schema.png)

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

![Install](/assets/k3s/k3s.install.gif)

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
![Validando](/assets/k3s/k3s.validando.gif)
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
![Alias](/assets/k3s/k3s.alias.gif)

## 8. Passo - Configurando o Metrics Server
Para que serve o Metrics Server?
O Metrics Server é um componente do Kubernetes que coleta métricas de uso de recursos de cada nó e pod do cluster, permitindo que o Kubernetes possa escalar os pods de acordo com a necessidade.

### 8.1 Metrics Server - Instalação
Baixe o arquivo de instalação do Metrics Server:
```bash
curl -LO https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 8.2 Metrics Server - Configuração
Altere o arquivo de instalação do Metrics Server, adicionando no tipo `Kind:Deployments` as seguintes linhas no spec do container:
```yaml
        command:
        - /metrics-server
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP
```
- Antes
![Metrics Server](/assets/metrics-server/antes.png)

- Depois
![Metrics Server](/assets/metrics-server/depois.png)


## 8. Passo - `Opcional` Removendo o K3S
```bash
ansible-playbook -i hosts.yaml k3s.uninstall.yaml
```
![Uninstall](/assets/k3s/k3s.uninstall.gif)

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
![Install](/assets/metallb/metallb.install.gif)
### 1.2 MetalLB - Criando o secret para o memberlist
```bash
k3s create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```
![Create](/assets/metallb/metallb.memberlist.secret.gif)

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
![IPPool](/assets/metallb/metallb.ippool.gif)


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
![L2Advertisement](/assets/metallb/metallb.l2advertisement.gif)


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
![Lens](/assets/lens/lens.1.png)

#### 2.2.2 Acessando o Catalog
![Lens](/assets/lens/lens.2.png)

#### 2.2.3 Adicionando o Cluster
![Lens](/assets/lens/lens.3.png)

#### 2.2.4 Selecionando o tipo do arquivo de configuração
![Lens](/assets/lens/lens.4.png)

#### 2.2.5 Adicionando a Configuração do Cluster
Adicione o arquivo de configuração do K3S gerado pelo playbook.
![Lens](/assets/lens/lens.5.png)

#### 2.2.6 Validando a conexão com o Cluster
![Lens](/assets/lens/lens.6.png)

#### 2.2.7 Acessando os recursos do Cluster
![Lens](/assets/lens/lens.7.png)


---
## 3. Passo - Configurando o Cloudflare
Para que iremos utilizar o Cloudflare?
- Caso sua provedora de internet não libere o IP público(como a minha), será necessário utilizar um serviço de *Tunneling*, para que seja possível acessar os serviços do cluster Kubernetes através de um domínio.

### 3.1 Cloudflare - Faça o Login
Acesse o site https://dash.cloudflare.com/login e faça o login com a sua conta. Caso não tenha uma conta, crie uma conta gratuita.

### 3.2 Cloudflare - Compre um domínio ou configure um domínio existente
Para criar o tunnel, será ter um domínio configurado no Cloudflare, caso não tenha um domínio, compre um domínio ou configure um domínio existente no Cloudflare.

### 3.3 Cloudflare - Criando o Tunnel
#### 3.3.1 Acesse o menu `Tunnels`