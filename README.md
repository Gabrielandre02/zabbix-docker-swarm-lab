# Zabbix Docker Swarm Lab

Deploy completo do Zabbix em Docker Swarm dentro de uma VM Vagrant.

## Estrutura do projeto
```markdown
.
├── Makefile
├── Vagrantfile
├── settings.yaml
├── deploy.sh
├── destroy.sh
└── ansible-deploy-full-zabbix
    ├── ansible.cfg
    ├── inventory
    │   └── hosts.ini
    ├── playbooks
    │   └── deploy-full-zabbix.yml
    └── roles
        └── zbx-docker
            ├── files
            │   ├── docker-compose.prod.yaml
            │   ├── docker-compose.traefik.yaml
            │   └── envs
            │       ├── dbzbx_prod.env
            │       ├── zabbix-frontend/common.env
            │       ├── zabbix-java/commom.env
            │       ├── zabbix-proxy/common.env
            │       └── zabbix-server/common.env
            ├── templates
            │   └── docker-compose.prod.yaml.j2
            ├── tasks/main.yml
            └── vars/main.yml
```

## Pré-requisitos
- Vagrant instalado.
- VirtualBox instalado (provider padrão do Vagrant) e com `VBoxManage` no PATH.
- Acesso ao `vagrant` via terminal (`vagrant --version`).

## Configurações principais
Edite `ansible-deploy-full-zabbix/roles/zbx-docker/vars/main.yml`:
- `zabbix_image_version`: versão das imagens Zabbix (ex.: `latest`).
- `grafana_image_version`: versão do Grafana.
- `zabbix_domain`: domínio usado nas URLs.
- `zabbix_stack_name`: nome da stack Swarm.
- `timescaledb_image`: imagem do PostgreSQL com TimescaleDB.
- `proxy_count`: quantidade de proxies.
- `proxy_base_port`: porta inicial dos proxies no host.
- `proxy_hostname_prefix`: prefixo de hostname dos proxies.

Edite `settings.yaml` (raiz) para ajustar o IP da VM.

## Deploy
```bash
make deploy
```

O `deploy.sh`:
- Sobe a VM com Vagrant.
- Aguarda o SSH ficar disponível.
- Atualiza o inventory com os dados do `vagrant ssh-config`.
- Mostra o IP da VM para você mapear o DNS local.
- Executa o playbook Ansible para instalar Docker e subir o Swarm.

## Acesso
Após o deploy, mapeie o IP da VM no seu DNS local ou `/etc/hosts`:
```bash
10.0.2.15 zabbix.exemplo.com.br
10.0.2.15 traefik.exemplo.com.br
10.0.2.15 grafana.exemplo.com.br
```

URLs:
- `zabbix.${zabbix_domain}`
- `traefik.${zabbix_domain}`
- `grafana.${zabbix_domain}`

Credenciais padrão:
- Zabbix: `Admin` / `zabbix`
- Grafana: `admin` / `admin`

## Remoção da infra
```bash
make destroy
```

## Observações
- Em Apple Silicon, a box padrão é `bento/oraclelinux-9`. Você pode sobrescrever com:
  `VAGRANT_BOX=alguma/box make deploy`
- A porta 8080 do host pode ser alterada:
  `VAGRANT_HOST_PORT=18080 make deploy`
- Para habilitar HTTPS automático, edite `ansible-deploy-full-zabbix/roles/zbx-docker/files/docker-compose.traefik.yaml`.
