# Instalação do Longhorn

1. Instale o Longhorn com o comando abaixo:

```bash
k3s apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.2/deploy/longhorn.yaml
```


2. Verifique se o Longhorn foi instalado com sucesso:

```bash
k3s kubectl get pods -n longhorn-system
```

3. Crie um StorageClass para Teste:
 - Execute o comando abaixo para criar o StorageClass:
  ```bash
  k3s apply -f .
  ```
