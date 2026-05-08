# Problèmes rencontrés et Solutions - Infrastructure Terraform

## Vue d'ensemble

Ce document documente les problèmes rencontrés lors de la création et du déploiement de l'infrastructure Terraform pour l'application e-commerce, ainsi que les solutions apportées.

---

## 1. Problème : Provisioners au niveau top-level

### Description du problème
Les blocs `provisioner` ne peuvent pas être utilisés au niveau top-level d'un fichier Terraform. Cela entraîne une erreur de syntaxe.

### Symptômes
```
Error: Unsupported block type on MODULE.resource_type.name
on <file>.tf line X: provisioner "type" {...}

Provisioners can only be used within a resource block.
```

### Cause
Les provisioners (local-exec, remote-exec, etc.) doivent obligatoirement être imbriqués à l'intérieur d'une ressource Terraform, jamais en top-level ou en bloc standalone.

### Solution appliquée
```hcl
# ❌ INCORRECT
provisioner "local-exec" {
  command = "echo 'Hello'"
}

resource "aws_instance" "example" {
  # ...
}

# ✅ CORRECT
resource "aws_instance" "example" {
  # ...
  
  provisioner "local-exec" {
    command = "echo 'Hello'"
  }
}
```

### Bonnes pratiques
- Les provisioners ne doivent être utilisés qu'en **dernier recours**
- Préférer **user_data** pour les tâches d'initialisation EC2 (utilisé dans ce projet)
- Préférer **cloud-init** ou **configuration management tools** (Ansible, Puppet) pour les tâches complexes

### Application dans ce projet
```hcl
resource "aws_instance" "eureka_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  
  # ✅ Utilisation de user_data au lieu de provisioners
  user_data = base64encode(templatefile("${path.module}/user-data-eureka.sh", {
    eureka_image = var.container_images.eureka
  }))
}
```

---

## 2. Problème : Lignes source/destination orphelines

### Description du problème
Des lignes de code Terraform comme `source`, `destination` ou d'autres directives écrites en dehors d'un bloc de ressource causent des erreurs de syntaxe.

### Symptômes
```
Error: Invalid or missing required argument
on <file>.tf line X: "source" "destination" ...

A block is required here.
```

### Cause
Toute directives ou arguments Terraform doivent être contenus **à l'intérieur d'un bloc** (resource, module, data, etc.). Les lignes orphelines ne sont pas valides.

### Solution appliquée
```hcl
# ❌ INCORRECT
source = "terraform-aws-modules/vpc/aws"
version = "~> 2.0"

module "vpc" {
  # ...
}

# ✅ CORRECT
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"
  
  # Configuration du module
  vpc_cidr = var.vpc_cidr
}
```

### Bonnes pratiques
- Toujours placer les arguments à l'intérieur du bloc approprié
- Utiliser les éditeurs avec validation Terraform pour détecter les erreurs
- Exécuter `terraform validate` avant de committer

### Référence dans ce projet
```hcl
# ✅ Configuration correcte dans provider.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "vocareum"
}
```

---

## 3. Problème : Dépendances circulaires entre instances

### Description du problème
Les dépendances entre instances EC2 peuvent créer des dépendances circulaires si mal configurées, empêchant Terraform de créer les ressources.

### Symptômes
```
Error: Cycle detected for resource

The resource dependency graph contains a cycle.
This is a provider issue that should be reported with the provider.
```

### Cause
- ActiveMQ a besoin d'être démarré pour que les services fonctionnent
- Les services ont besoin d'Eureka pour la découverte
- Mais Eureka peut avoir besoin de dépendre d'autres services pour son démarrage

### Solution appliquée
**Ordre de création défini explicitement** :
```hcl
# Étape 1 : Eureka (aucune dépendance)
resource "aws_instance" "eureka_server" {
  # Pas de depends_on
}

# Étape 2 : ActiveMQ (aucune dépendance)
resource "aws_instance" "activemq" {
  # Pas de depends_on
}

# Étape 3 : Services métier (dépendent d'Eureka et ActiveMQ)
resource "aws_instance" "product_service" {
  depends_on = [aws_instance.eureka_server, aws_instance.activemq]
}

resource "aws_instance" "cart_service" {
  depends_on = [aws_instance.eureka_server, aws_instance.activemq]
}

# Étape 4 : API Gateway (dépend de tout)
resource "aws_instance" "api_gateway" {
  depends_on = [
    aws_instance.eureka_server,
    aws_instance.product_service,
    aws_instance.cart_service
  ]
}
```

### Bonnes pratiques
- Utiliser `depends_on` **explicitement** seulement si nécessaire
- Laisser Terraform déduire les dépendances via les références d'attributs `${resource.id}`
- Éviter les références circulaires
- Documenter la raison des `depends_on` explicites

### Améliorations futures
- Utiliser un orchestrateur (Kubernetes, Docker Compose) pour gérer l'ordre de démarrage
- Implémenter des health checks dans les user-data scripts pour attendre les dépendances

---

## 4. Problème : AMI ID incorrect ou introuvable

### Description du problème
Utiliser un AMI ID fixe qui n'existe pas ou est obsolète dans la région cible.

### Symptômes
```
Error: InvalidAMIID.NotFound: The image id '[ami-xxxxxxxxx]' does not exist

The specified AMI does not exist, or you do not have access to it.
```

### Cause
- AMI ID codé en dur sans vérification de disponibilité
- AMI spécifique à une région mais utilisé dans une autre
- AMI supprimé ou expiré

### Solution appliquée
```hcl
# ✅ Data source dynamique pour récupérer l'AMI le plus récent
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Utilisation dans les instances
resource "aws_instance" "eureka_server" {
  ami = data.aws_ami.amazon_linux_2.id  # Dynamique
  # ...
}
```

### Bonnes pratiques
- Toujours utiliser des data sources pour découvrir les AMIs
- Spécifier des filtres clairs (propriétaire, nom pattern, virtualisation)
- Documenter quelle image est utilisée
- Utiliser `most_recent = true` pour éviter les AMIs obsolètes

---

## 5. Problème : Ports bloqués par les Security Groups

### Description du problème
Les instances ne peuvent pas communiquer car les ports nécessaires ne sont pas autorisés par les security groups.

### Symptômes
- Timeout lors de la connexion entre services
- Health checks qui échouent
- Services impossibles à joindre via ALB
```
timeout: connection refused
```

### Cause
- Oubli d'ajouter les règles d'ingress pour les ports des services
- Ordre des dépendances : ALB crée avant que EC2 security group soit défini
- Règles d'egress manquantes ou trop restrictives

### Solution appliquée
```hcl
# Ingress depuis ALB vers API Gateway
ingress {
  from_port       = var.container_port_gateway  # 8080
  to_port         = var.container_port_gateway
  protocol        = "tcp"
  security_groups = [aws_security_group.alb.id]  # Depuis ALB SG
}

# Ingress inter-EC2 pour la communication interne
ingress {
  from_port = 0
  to_port   = 65535
  protocol  = "tcp"
  self      = true  # Entre instances du même SG
}

# Ingress spécifique ActiveMQ
ingress {
  from_port = var.container_port_activemq  # 61616
  to_port   = var.container_port_activemq
  protocol  = "tcp"
  self      = true
}

# Admin console ActiveMQ (seulement depuis VPC)
ingress {
  from_port   = 8161
  to_port     = 8161
  protocol    = "tcp"
  cidr_blocks = [var.vpc_cidr]
}

# Egress : tout autorisé pour sortir
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

### Bonnes pratiques
- **Principe du moindre privilège** : Ne pas utiliser `0.0.0.0/0` sauf si nécessaire (SSH en dev seulement)
- Référencer les security groups plutôt que les CIDR blocks quand possible
- Autoriser explicitement chaque port nécessaire
- Documenter le rôle de chaque règle
- Tester la connectivité après déploiement

### Checklist de validation
- [ ] ALB → API Gateway (port 8080)
- [ ] ALB → Product Service (port 8081)
- [ ] ALB → Cart Service (port 8082)
- [ ] Instances ↔ Eureka (port 8761)
- [ ] Instances ↔ ActiveMQ (port 61616)
- [ ] Instances → Internet (pour docker pull)

---

## 6. Problème : Variables non définies lors du apply

### Description du problème
Oublier de fournir les valeurs requises pour les variables lors de `terraform apply` ou utiliser des noms différents.

### Symptômes
```
Error: Reference to undefined variable "container_images"
```

### Cause
- Variable définie dans `variables.tf` mais pas de valeur par défaut
- Fichier `.tfvars` manquant ou nommé incorrectement
- Variable requise dans le code mais pas déclarée dans `variables.tf`

### Solution appliquée
```hcl
# ✅ Variables avec valeurs par défaut dans variables.tf
variable "container_images" {
  description = "Container images for services"
  type = object({
    api_gateway = string
    product     = string
    cart        = string
    eureka      = string
    activemq    = string
  })
  default = {
    api_gateway = "eyahaddad/api-gateway:latest"
    product     = "eyahaddad/product-service:latest"
    cart        = "eyahaddad/cart-service:latest"
    eureka      = "eyahaddad/eureka-server:latest"
    activemq    = "apache/activemq-classic:latest"
  }
}
```

### Bonnes pratiques
- Toujours fournir des **valeurs par défaut** pour les variables non-sensibles
- Créer un fichier `terraform.tfvars.example` avec la structure attendue
- Documenter chaque variable dans sa description
- Valider les variables dans les ressources si nécessaire
- Utiliser des variables sensibles pour les secrets (AWS_SECRET_ACCESS_KEY, etc.)

### Commandes applicables
```bash
# Utiliser un fichier tfvars spécifique
terraform apply -var-file="production.tfvars"

# Passer une variable directement
terraform apply -var="aws_region=eu-west-1"

# Utiliser les env vars
export TF_VAR_aws_region="eu-west-1"
terraform apply
```

---

## 7. Problème : Clé privée EC2 introuvable après déploiement

### Description du problème
Après un `terraform apply`, la clé privée est générée mais l'utilisateur ne sait pas où elle est stockée ou elle est perdue.

### Symptômes
```
Error: Cannot connect to instance via SSH
Permission denied (publickey)
```

### Cause
- Clé privée stockée localement mais chemin non documenté
- Permissions de fichier incorrectes (trop ouvertes)
- Clé supprimée ou déplacée accidentellement

### Solution appliquée
```hcl
# ✅ Génération et stockage sécurisé de la clé
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project_name}-ec2-key-2026-1"
  public_key = tls_private_key.ec2.public_key_openssh
}

# Sauvegarde locale avec permissions restrictives
resource "local_file" "ec2_private_key" {
  content         = tls_private_key.ec2.private_key_pem
  filename        = "${path.module}/${var.project_name}-ec2-key-2026-1.pem"
  file_permission = "0600"  # Lecture/écriture owner seulement
}
```

### Bonnes pratiques
- Toujours sauvegarder les clés privées dans un gestionnaire de secrets (AWS Secrets Manager, HashiCorp Vault)
- **Ne jamais** committer les clés privées dans Git
- Ajouter `.pem` files et clés privées à `.gitignore`
- Documenter où les clés sont stockées
- Utiliser des permissions de fichier strictes (0600)
- Implémenter la rotation des clés

### Amélioration future
```hcl
# Utiliser AWS Secrets Manager
resource "aws_secretsmanager_secret" "ec2_key" {
  name = "${var.project_name}-ec2-key"
}

resource "aws_secretsmanager_secret_version" "ec2_key" {
  secret_id      = aws_secretsmanager_secret.ec2_key.id
  secret_string  = tls_private_key.ec2.private_key_pem
}
```

---

## 8. Problème : Absence de NAT Gateway pour accès Internet depuis subnets privés

### Description du problème
Les instances dans les subnets privés ne peuvent pas accéder à Internet pour télécharger les images Docker.

### Symptômes
```
Failed to connect to ... during docker pull
Error: network is unreachable
timeout
```

### Cause
- Subnets privés sans route vers Internet
- NAT Gateway non configurée ou non attaché
- Route table privée non associée au NAT Gateway

### Solution appliquée
```hcl
# ✅ Création des NAT Gateways (un par subnet public)
resource "aws_eip" "nat_gateway" {
  count  = var.enable_nat_gateway ? length(var.public_subnet_cidrs) : 0
  domain = "vpc"
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? length(var.public_subnet_cidrs) : 0
  allocation_id = aws_eip.nat_gateway[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on = [aws_internet_gateway.main]
}

# ✅ Route tables privées vers NAT Gateway
resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? length(var.private_subnet_cidrs) : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
}

# ✅ Association des subnets privés aux route tables
resource "aws_route_table_association" "private" {
  count          = var.enable_nat_gateway ? length(aws_subnet.private) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

### Bonnes pratiques
- Utiliser une NAT Gateway **par AZ** pour la haute disponibilité
- Mettre la création de NAT Gateway en tant que variable optionnelle (implication de coûts)
- Documenter les coûts associés (NAT Gateway coûte ~$45/mois par instance)
- Tester la connectivité sortante après déploiement

### Commande de test
```bash
# SSH vers une instance privée via bastion
ssh -i ecommerce-ec2-key-2026-1.pem ec2-user@<private-ip>

# Vérifier l'accès Internet
curl -I https://docker.io
docker pull my-image:latest
```

---

## 9. Problème : Santé des instances EC2 vérifiée trop tôt

### Description du problème
L'ALB marque les instances comme unhealthy parce que les services n'ont pas eu assez de temps pour démarrer.

### Symptômes
```
Target health: unhealthy
Status reason: Health checks failed with these codes: [503, 500]
```

### Cause
- Health check lance avant que le service soit prêt
- User-data script n'a pas complété
- Dépendances (Eureka, ActiveMQ) pas encore disponibles

### Solution appliquée
```hcl
# ✅ Health check avec seuils tolérants
health_check {
  healthy_threshold   = 3      # 3 tests OK consécutifs requis
  unhealthy_threshold = 3      # 3 tests KO consécutifs avant démarquage
  timeout             = 5      # 5 secondes timeout par test
  interval            = 30     # Test tous les 30 secondes
  path                = "/actuator/health"
  matcher             = "200"  # Accepte seulement HTTP 200
}
```

### Bonnes pratiques dans user-data
```bash
#!/bin/bash
set -e

# Attendre Eureka avant de démarrer le service
for i in {1..30}; do
  if curl -sf http://${eureka_server}:8761/eureka/apps > /dev/null; then
    echo "Eureka is available"
    break
  fi
  echo "Waiting for Eureka (attempt $i)..."
  sleep 2
done

# Attendre que le service soit vraiment prêt
for i in {1..30}; do
  if curl -sf http://<service-private-ip>:${port}/actuator/health | grep -q "UP"; then
    echo "Service is UP"
    exit 0
  fi
  echo "Waiting for service to be healthy..."
  sleep 3
done

echo "Service did not become healthy in time"
exit 1
```

### Améliorations futures
- Augmenter `interval` à 60 secondes après le déploiement initial
- Implémenter des métriques CloudWatch pour monitorer la santé
- Utiliser des tags personnalisés pour identifier les instances en transition

---

## 10. Problème : Terraform state corrompu ou désynchronisé

### Description du problème
Le fichier `terraform.tfstate` est desynchronisé avec les ressources réelles sur AWS, ou il est corrompu.

### Symptômes
```
Error: Error reading EC2 Instance: InvalidInstanceID.NotFound
Error refreshing state

The Terraform state file is corrupt
```

### Cause
- Suppression manuelle de ressources via AWS Console
- Tentative de création échouée laissant state incohérent
- Problèmes de concurrence (plusieurs terraform apply simultanés)
- Fichier state corrompus par édition manuelle

### Solution appliquée
```hcl
# ✅ Backup automatique du state (fourni par Terraform)
# Terraform crée automatiquement terraform.tfstate.backup

# ✅ Vérifier l'état actuel
terraform state list      # Lister les ressources
terraform state show aws_instance.eureka_server
terraform state pull     # Consulter le state brut (JSON)

# ✅ Récupérer l'état depuis AWS
terraform refresh        # Mettre à jour le state sans appliquer

# ✅ Restaurer une version antérieure
terraform state pull > backup.json
# Éditer backup.json si nécessaire
cat backup.json | terraform state push -
```

### Bonnes pratiques
- Activer **S3 backend** avec encryption et versioning
```hcl
terraform {
  backend "s3" {
    bucket         = "ecommerce-terraform-state"
    key            = "ecommerce/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```
- Implémenter le **state locking** pour éviter les écritures simultanées
- **Jamais** éditer le state manuellement sauf en dernier recours
- Faire des **backups réguliers** du state
- Ajouter `.gitignore` pour `.tfstate` et `.tfstate*`

### Commandes de maintenance
```bash
# Supprimer une ressource du state (sans la détruire)
terraform state rm aws_instance.example

# Importer une ressource existante
terraform import aws_instance.example i-0123456789abcdef0

# Rafraîchir le state sans changement
terraform refresh

# Forcer un re-planning
terraform plan -refresh=true
```

---

## 11. Problème : Images Docker non trouvées au pull

### Description du problème
Les user-data scripts échouent parce que `docker pull` ne trouve pas l'image spécifiée.

### Symptômes
```
Error response from daemon: pull access denied for eyahaddad/api-gateway, 
repository does not exist or may require 'docker login'
```

### Cause
- Image n'existe pas sur Docker Hub
- Tag incorrect ou obsolète
- Authentification nécessaire mais pas configurée

### Solution appliquée
```hcl
# ✅ Variables avec images par défaut validées
variable "container_images" {
  description = "Container images for services"
  type = object({
    api_gateway = string
    product     = string
    cart        = string
    eureka      = string
    activemq    = string
  })
  default = {
    api_gateway = "eyahaddad/api-gateway:latest"
    product     = "eyahaddad/product-service:latest"
    cart        = "eyahaddad/cart-service:latest"
    eureka      = "eyahaddad/eureka-server:latest"
    activemq    = "apache/activemq-classic:latest"  # Image officielle
  }
}
```

### Bonnes pratiques
- Utiliser des **versions tag spécifiques** au lieu de `:latest`
```hcl
api_gateway = "eyahaddad/api-gateway:1.0.0"  # ✅ Mieux
api_gateway = "eyahaddad/api-gateway:latest" # ⚠️  Peut changer
```
- Valider que les images existent avant déploiement
```bash
docker pull eyahaddad/api-gateway:latest
```
- Implémenter un **ECR privé** pour les images internes
- Ajouter des mécanismes de retry dans user-data
```bash
for i in {1..5}; do
  docker pull ${service_image} && break
  sleep 5
done
```

---

## 12. Problème : Count et For_each utilisés incorrectement

### Description du problème
Utiliser `count` et `for_each` incorrectement cause des erreurs ou des comportements inattendus lors de la destruction.

### Symptômes
```
Error: Invalid for_each argument

element index out of range
```

### Cause
- Mélanger `count` et `for_each` pour la même ressource
- Utiliser une variable list qui change et invalide les index
- Références incorrectes aux éléments

### Solution appliquée
```hcl
# ✅ Utilisation cohérente de count pour les subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

# ✅ Référence correcte aux ressources créées par count
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

### Bonnes pratiques
- Choisir **count** pour des listes de ressources similaires
- Choisir **for_each** pour des maps ou configurations différentes par élément
- Ne **jamais** mélanger count et for_each pour la même ressource
- Utiliser des variables stables pour count/for_each (ne pas changer l'ordre)
- Documenter la raison du count/for_each

---

## Résumé des solutions critiques

| Problème | Impact | Solution |
|----------|--------|----------|
| Provisioners top-level | Syntaxe invalide | Imbriqués dans resource, utiliser user_data |
| Lignes orphelines | Syntaxe invalide | Placer dans blocs appropriés |
| Dépendances circulaires | Création bloquée | Ordre explicite via depends_on |
| AMI hard-codée | Instance non créée | Data source dynamique |
| Ports non autorisés | Connectivité perdue | Security groups explicites |
| NAT Gateway manquante | Pas d'accès Internet | NAT Gateway par subnet public |
| Health checks échoués | Instances marked unhealthy | Retries + waits dans user-data |
| State corrompu | État inconnu | S3 backend + locking |
| Images Docker manquantes | Déploiement échoué | Tags spécifiques, ECR |
| Count/for_each mélangés | Comportement imprévisible | Utiliser un seul par ressource |

---

## Commandes de diagnostic utiles

```bash
# Valider la configuration
terraform validate

# Vérifier la syntaxe
terraform fmt -check -recursive .

# Voir le plan sans appliquer
terraform plan -out=tfplan
terraform show tfplan

# Appliquer avec auto-approval
terraform apply tfplan

# Voir l'état actuel
terraform state list
terraform state show <resource-name>

# Détruire avec caution
terraform plan -destroy
terraform destroy

# Debug verbose
TF_LOG=DEBUG terraform apply

# Graphe des dépendances
terraform graph | dot -Tpng > graph.png
```

---

## Checklist pré-déploiement

- [ ] `terraform validate` passe sans erreur
- [ ] `terraform fmt -recursive .` appliqué et committés
- [ ] Toutes les variables ont une description et (idéalement) une valeur par défaut
- [ ] Aucun value hard-codée en dehors de variables.tf
- [ ] Security groups définis et testés
- [ ] NAT Gateway activé si instances privées ont besoin d'Internet
- [ ] User-data scripts testés localement
- [ ] Clés privées générées et stockées de manière sécurisée
- [ ] Backend d'état configuré (S3 + DynamoDB pour prod)
- [ ] Tags consistants appliqués à toutes les ressources
- [ ] Plan reviewed avant apply
- [ ] Backups de state disponibles
