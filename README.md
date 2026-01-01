# Zabbix Docker Swarm Lab

Full Zabbix deployment on Docker Swarm inside a Vagrant VM.

## Project structure
```markdown
.
├── .gitignore
├── Makefile
├── Vagrantfile
├── settings.yaml
├── deploy.sh
├── stop.sh
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
            │   ├── docker-compose.traefik.yaml
            │   └── envs
            │       ├── dbzbx_prod.env
            │       ├── zabbix-frontend/common.env
            │       ├── zabbix-java/commom.env
            │       ├── zabbix-proxy/common.env
            │       └── zabbix-server/common.env
            ├── templates
            │   ├── certs-traefik.yml.j2
            │   └── docker-compose.prod.yaml.j2
            ├── tasks/main.yml
            └── vars/main.yml
```

## Prerequisites
- Vagrant installed.
- VirtualBox installed (Vagrant default provider) and `VBoxManage` in PATH.
- CLI access to `vagrant` (`vagrant --version`).

## Main configuration
Edit `ansible-deploy-full-zabbix/roles/zbx-docker/vars/main.yml`:
- `zabbix_image_version`: Zabbix image version (e.g. `latest`).
- `grafana_image_version`: Grafana version.
- `zabbix_domain`: domain used in URLs.
- `zabbix_stack_name`: Swarm stack name.
- `timescaledb_image`: PostgreSQL + TimescaleDB image.
- `db_max_connections`: PostgreSQL max connections.
- `proxy_count`: number of proxies.
- `proxy_base_port`: base host port for proxies.
- `proxy_hostname_prefix`: proxy hostname prefix.
- `docker_min_version`: minimum Docker version.
- `firewall_zone`: firewalld zone used.
- `cleanup_clone_directory`: remove deploy directory after execution.
- `force_hash_check`: force hash recalculation.

Edit `settings.yaml` (root) to set the VM IP.

## Deploy
```bash
make deploy
```

`deploy.sh`:
- Boots the VM with Vagrant.
- Waits for SSH to be available.
- Updates inventory using `vagrant ssh-config`.
- Prints the VM IP for local DNS mapping.
- Runs the Ansible playbook to install Docker and deploy Swarm.

## Stop the VM
```bash
make stop
```

## Access
After deploy, map the VM IP in your local DNS or `/etc/hosts`:
```bash
10.0.2.15 zabbix.exemplo.com.br
10.0.2.15 traefik.exemplo.com.br
10.0.2.15 grafana.exemplo.com.br
```

URLs:
- `zabbix.${zabbix_domain}`
- `traefik.${zabbix_domain}`
- `grafana.${zabbix_domain}`

Default credentials:
- Zabbix: `Admin` / `zabbix`
- Grafana: `admin` / `admin`

## Traefik TLS
- The playbook generates self-signed certificates based on `zabbix_domain`.
- Files are created in `{{ clone_directory }}/data_internal/traefik/`.
- Traefik uses the file provider with `certs-traefik.yml`.

## Remove the environment
```bash
make destroy
```

## Notes
- On Apple Silicon, the default box is `bento/oraclelinux-9`. Override with:
  `VAGRANT_BOX=some/box make deploy`
- Host ports exposed are 80 and 443. Override with:
  `VAGRANT_HTTP_PORT=8081 VAGRANT_HTTPS_PORT=8443 make deploy`
- To enable automatic HTTPS redirect, edit `ansible-deploy-full-zabbix/roles/zbx-docker/files/docker-compose.traefik.yaml`.
