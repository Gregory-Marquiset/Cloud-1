# Cloud-1

Deploiement entierement automatise d'une infrastructure WordPress conteneurisee,
sur plusieurs serveurs en parallele.

Le projet couvre deux etages :

- **Terraform** cree les serveurs et genere l'inventaire Ansible (extra, hors sujet)
- **Ansible** provisionne les serveurs et deploie la stack Docker (partie obligatoire)

---

## Architecture

```
                          internet
                             |
                     22 / 80 / 443  (seuls ports ouverts, UFW)
                             |
  +--------------------------|--------------------------------+
  |  serveur Ubuntu 22.04    v                                 |
  |                       +-------+                            |
  |                       | nginx |  TLS, routage par URL      |
  |                       +---+---+                            |
  |                    FastCGI | 9000                          |
  |            +---------------+---------------+               |
  |            v                               v               |
  |   +-----------------+           +--------------------+     |
  |   | wordpress (fpm) |           | phpmyadmin (fpm)   |     |
  |   +--------+--------+           +---------+----------+     |
  |            |                              |                |
  |            +--------------+---------------+                |
  |                           v                                |
  |                    +-------------+                         |
  |                    |   mariadb   |  aucun port publie      |
  |                    +-------------+                         |
  |                                                            |
  |            reseau interne "backend" (Docker)               |
  +------------------------------------------------------------+
```

Routage assure par nginx :

| URL            | destination              |
|----------------|--------------------------|
| `http://...`   | redirection 301 en HTTPS |
| `/`            | WordPress                |
| `/phpmyadmin/` | phpMyAdmin               |

---

## Choix techniques

**Images `-fpm`, pas `-apache`.** Le sujet impose un process par conteneur. Les
variantes Apache des images officielles embarquent serveur web *et* PHP dans le
meme conteneur. Avec `-fpm`, PHP tourne seul et nginx lui parle en FastCGI.

**Un seul conteneur publie des ports.** nginx expose 80 et 443 ; MariaDB et les
deux php-fpm n'ont que le reseau interne. La base est donc injoignable depuis
l'exterieur par construction, pas seulement grace au pare-feu. UFW est la seconde
couche, utile pour tout ce qui n'est pas conteneurise -- Docker ecrit directement
dans iptables et contourne UFW pour ses propres ports publies.

**Volumes nommes.** `db_data`, `wp_data` et `pma_data` survivent aux redemarrages
et aux recreations de conteneurs : articles, comptes et medias sont preserves.
Combines a `restart: unless-stopped` et au service Docker active au boot, ils
satisfont les deux exigences de reprise apres reboot.

**nginx resout ses upstreams via des variables.** `set $upstream_wp wordpress;`
puis `fastcgi_pass $upstream_wp:9000;`. Sans cela nginx resout les noms au
demarrage et refuse de demarrer si un conteneur n'est pas encore la -- au boot du
serveur, il entrait en boucle de crash. Avec une variable il resout a chaque
requete : un upstream momentanement absent donne un 502 passager au lieu d'un
plantage.

**Traduction de chemin pour phpMyAdmin.** nginx monte les fichiers de phpMyAdmin
en `/var/www/phpmyadmin` (pour servir le statique) mais annonce
`SCRIPT_FILENAME /var/www/html/$1` au conteneur php-fpm, ou les fichiers se
trouvent reellement. Un chemin FastCGI doit exister dans le conteneur qui execute
le PHP, pas dans celui qui sert la requete.

**Roles Ansible separes.** `common` (paquets de base, pare-feu), `docker` (moteur
et plugin compose depuis le depot officiel), `app` (stack applicative). Un role =
une responsabilite : on peut rejouer `docker` sans toucher a l'application, et
`common` est reutilisable ailleurs.

**Extra Terraform.** Le sujet ne demande qu'Ansible. Terraform apporte ici deux
choses : les serveurs eux-memes sont decrits en code (une instance fraiche part
toujours de la meme image cloud officielle, sans template prepare a la main), et
l'inventaire Ansible est *genere* a partir des adresses declarees -- aucune IP
n'est recopiee a la main entre les deux outils.

---

## Prerequis

Sur la machine de controle :

- Terraform >= 1.5
- Ansible >= 2.15 avec les collections `community.general` et `community.docker`
- une paire de cles SSH

Sur l'hyperviseur Proxmox :

- un jeton d'API
- un utilisateur SSH dedie (le provider passe par SSH pour deposer les snippets
  cloud-init, l'API ne le permet pas). Un compte `terraform` avec un sudoers
  restreint a `pvesm`, `qm` et `tee /var/lib/vz/*` suffit -- pas besoin de root.

Les serveurs cibles n'ont besoin de rien de particulier : Ubuntu 22.04, un demon
SSH et Python, conformement au sujet.

---

## Structure du depot

```
cloud-1/
├── terraform/          creation des serveurs + generation de l'inventaire
│   ├── versions.tf     providers et versions figees
│   ├── provider.tf     authentification (API par variables d'env, SSH pour les snippets)
│   ├── variables.tf    parametres, dont la map "instances"
│   ├── main.tf         image cloud, VMs, calcul des adresses
│   ├── cloud-init.tf   configuration de premier demarrage
│   ├── inventory.tf    ecriture de ansible/inventory/hosts.yml
│   └── outputs.tf
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml        playbook principal
│   ├── group_vars/cloud1/
│   │   ├── vars.yml    variables en clair
│   │   └── vault.yml   mots de passe, chiffres (AES256)
│   ├── inventory/      genere par Terraform, ne pas editer
│   └── roles/
│       ├── common/     paquets de base, UFW
│       ├── docker/     moteur Docker et plugin compose
│       └── app/        stack applicative, TLS, .env
└── docker/
    ├── docker-compose.yml
    └── nginx.conf
```

---

## Deploiement

### 1. Configuration

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Y renseigner sa cle publique SSH. Les identifiants Proxmox passent par
l'environnement, jamais par le depot :

```bash
export PROXMOX_VE_ENDPOINT="https://<hyperviseur>:8006/"
export PROXMOX_VE_API_TOKEN="<utilisateur>@<realm>!<token>=<secret>"
```

### 2. Creer les serveurs

```bash
cd terraform
terraform init
terraform apply
```

Terraform telecharge l'image Ubuntu 22.04, cree les VMs et ecrit
`ansible/inventory/hosts.yml`.

Le nombre de serveurs se regle dans la variable `instances` : ajouter une entree
suffit a deployer un serveur de plus.

```hcl
instances = {
  "cloud-1-srv-1" = { vm_id = 130, ip = "192.168.1.210/24" }
  "cloud-1-srv-2" = { vm_id = 131, ip = "192.168.1.211/24" }
}
```

### 3. Deployer l'application

```bash
cd ../ansible
ansible-playbook site.yml
```

Le site est ensuite accessible en HTTPS sur chacune des adresses declarees.

---

## Secrets

Aucun mot de passe n'apparait dans le depot.

- Les mots de passe de la base vivent dans `group_vars/cloud1/vault.yml`, chiffre
  par Ansible Vault. Ce fichier est versionne ; sa cle ne l'est pas.
- `group_vars/cloud1/vars.yml` ne contient que des references
  (`db_password: "{{ vault_db_password }}"`). Cette indirection garde les
  variables greppables : un fichier chiffre ne l'est pas.
- Le role `app` genere `/opt/cloud-1/.env` sur le serveur cible, en 0600. C'est le
  seul endroit ou les mots de passe existent en clair.
- `.vault-pass`, `terraform.tfvars`, l'etat Terraform, le `.env` et les
  certificats sont exclus par `.gitignore`.

Recreer le vault sur une nouvelle machine de controle :

```bash
cd ansible
openssl rand -base64 32 > .vault-pass && chmod 600 .vault-pass
ansible-vault create group_vars/cloud1/vault.yml
```

```yaml
vault_db_root_password: "..."
vault_db_password: "..."
```

---

## TLS

Le role `app` genere un certificat auto-signe au premier deploiement, valable un
an. La tache utilise `creates:` : le certificat n'est pas regenere aux executions
suivantes, ce qui preserve l'idempotence.

Le navigateur avertira que le certificat n'est pas reconnu -- c'est attendu,
aucune autorite ne le signe. Avec un nom de domaine, remplacer le certificat par
un certificat Let's Encrypt et renseigner `server_name`.

---

## Validation

| Exigence | Verification |
|---|---|
| Deploiement automatise | `terraform apply` puis `ansible-playbook site.yml` |
| Plusieurs serveurs en parallele | deux serveurs deployes par le meme playbook |
| Redemarrage automatique | apres `reboot`, la stack remonte seule |
| Persistance des donnees | articles et comptes intacts apres reboot |
| Un process par conteneur | images `-fpm`, nginx separe |
| Ports 22/80/443 seuls ouverts | scan des ports depuis l'exterieur |
| Base injoignable de l'exterieur | port 3306 ferme, aucun port publie |
| TLS | `openssl s_client` : TLSv1.3 |
| Routage par URL | `/` et `/phpmyadmin/` |
| Instance fraiche | `terraform destroy` puis redeploiement complet |
| Idempotence | second passage : `changed=0` sur Ansible et Terraform |
| Aucun secret en dur | Ansible Vault |

---

## Utilisation de l'IA

Le sujet demande d'etre transparent sur ce point.

Ce projet a ete realise avec Claude (Anthropic) comme partenaire de travail.
L'assistant a servi a expliquer les mecanismes en jeu (resolution FastCGI,
resolution DNS des upstreams nginx, structure d'une tache Ansible, idempotence),
a relire le code et a aider au diagnostic des pannes a partir des logs.

Les fichiers de configuration ont ete ecrits a la main. Les pannes rencontrees --
healthcheck MariaDB obsolete depuis la version 11.4, boucle de crash de nginx au
demarrage, derive des adresses en DHCP -- ont ete diagnostiquees en lisant les
logs, puis corrigees en comprenant la cause plutot qu'en appliquant une solution
toute faite.

Les decisions d'architecture listees plus haut sont assumees et defendables :
chacune repond a une contrainte du sujet ou a un probleme rencontre pendant le
developpement.
