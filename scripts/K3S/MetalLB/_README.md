# Instalação do MetalLB

1. Instale o MetalLB com o comando abaixo:

```bash
k3s apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
```


2. Criar um Pool de IPs para o MetalLB:

```bash
k3s apply -f .
```
