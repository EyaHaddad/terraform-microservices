# Infrastructure Terraform - Documentation Technique

## Vue d'ensemble

Cette infrastructure Terraform déploie une architecture microservices complète sur AWS pour l'application e-commerce. Elle comprend :
- Un VPC avec subnets publics et privés
- Un Application Load Balancer (ALB) pour le routage du trafic
- Des instances EC2 pour les microservices (API Gateway, Product Service, Cart Service, Eureka Server, ActiveMQ)
- Des groupes de sécurité pour le contrôle d'accès
- Une infrastructure d'auto-scaling avec des launch templates

---

## Structure des fichiers

| Fichier | Description |
|---------|-------------|
| `provider.tf` | Configuration des fournisseurs Terraform (AWS, TLS, Local, Random) |
| `variables.tf` | Définition de toutes les variables d'entrée |
| `outputs.tf` | Outputs exposant les données importantes après déploiement |
| `vpc.tf` | Ressources VPC (VPC, subnets, Internet Gateway, NAT Gateway, route tables) |
| `ec2.tf` | Instances EC2 pour les microservices et la gestion des clés |
| `alb.tf` | Application Load Balancer et target groups |
| `autoscaling.tf` | Launch templates et Auto Scaling Groups |
| `iam.tf` | Configuration IAM (CloudWatch logs) |

---

## Configuration du Fournisseur (provider.tf)

### Versions requises
- **Terraform** : >= 1.0
- **AWS Provider** : ~> 5.0
- **TLS Provider** : ~> 4.0
- **Local Provider** : ~> 2.0
- **Random Provider** : ~> 3.0

### Paramètres AWS
```hcl
provider "aws" {
  region  = var.aws_region              # Région par défaut : us-east-1
  profile = "vocareum"                  # Profil AWS configuré localement
  
  skip_credentials_validation = true    # Validation des credentials désactivée
  skip_metadata_api_check     = true    # Vérification des métadonnées AWS désactivée
  skip_requesting_account_id  = true    # Requête de l'ID compte désactivée
}
```

**Backend d'état** : Commenté par défaut (S3 backend disponible en option)

---

## Variables de configuration (variables.tf)

### Variables générales

| Variable | Type | Valeur par défaut | Description |
|----------|------|-------------------|-------------|
| `aws_region` | string | `us-east-1` | Région AWS pour le déploiement |
| `environment` | string | `dev` | Environnement (dev, staging, prod) |
| `project_name` | string | `ecommerce` | Nom du projet pour les tags de ressources |
| `jar_bucket_name` | string | `ecommerce-jars-bucket` | Nom du bucket S3 pour les fichiers JAR |

### Variables de réseau

| Variable | Type | Valeur par défaut | Description |
|----------|------|-------------------|-------------|
| `vpc_cidr` | string | `10.0.0.0/16` | Bloc CIDR du VPC |
| `public_subnet_cidrs` | list(string) | `["10.0.1.0/24", "10.0.2.0/24"]` | Bloc CIDR des subnets publics |
| `private_subnet_cidrs` | list(string) | `["10.0.10.0/24", "10.0.11.0/24"]` | Bloc CIDR des subnets privés |
| `enable_nat_gateway` | bool | `true` | Active les NAT Gateways pour accès Internet depuis subnets privés |

### Variables de ports et services

| Variable | Type | Valeur par défaut | Description |
|----------|------|-------------------|-------------|
| `container_port_gateway` | number | `8080` | Port du conteneur API Gateway |
| `container_port_product` | number | `8081` | Port du conteneur Product Service |
| `container_port_cart` | number | `8082` | Port du conteneur Cart Service |
| `container_port_eureka` | number | `8761` | Port du conteneur Eureka Server |
| `container_port_activemq` | number | `61616` | Port du conteneur ActiveMQ |

### Variables ECS et conteneurs

| Variable | Type | Valeur par défaut | Description |
|----------|------|-------------------|-------------|
| `ecs_task_cpu` | string | `256` | Unités CPU pour les tâches ECS (256, 512, 1024, 2048, 4096) |
| `ecs_task_memory` | string | `512` | Mémoire en MB pour les tâches ECS (512, 1024, 2048, 4096, 8192) |
| `desired_count` | number | `1` | Nombre de tâches souhaité pour chaque service |
| `container_images` | object | Voir ci-dessous | Images Docker pour les services |
| `log_retention_days` | number | `7` | Rétention des logs CloudWatch en jours |

### Images Docker (container_images)
```hcl
{
  api_gateway = "eyahaddad/api-gateway:latest"
  product     = "eyahaddad/product-service:latest"
  cart        = "eyahaddad/cart-service:latest"
  eureka      = "eyahaddad/eureka-server:latest"
  activemq    = "apache/activemq-classic:latest"
}
```

---

## Ressources VPC (vpc.tf)

### VPC Principal
```hcl
aws_vpc.main {
  cidr_block           = var.vpc_cidr           # 10.0.0.0/16
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```
VPC contenant toute l'infrastructure avec support DNS activé.

### Internet Gateway
```hcl
aws_internet_gateway.main {
  vpc_id = aws_vpc.main.id
}
```
Permet la communication entre le VPC et Internet.

### Subnets publics
```hcl
aws_subnet.public (count = 2) {
  cidr_block              = var.public_subnet_cidrs[index]
  availability_zone       = Dynamique (2 AZ différentes)
  map_public_ip_on_launch = true
}
```
- **Nombre** : 2 subnets (configurable par variable)
- **Localisation** : 2 zones de disponibilité différentes
- **Attribution IP publique** : Activée automatiquement

### Subnets privés
```hcl
aws_subnet.private (count = 2) {
  cidr_block = var.private_subnet_cidrs[index]
  availability_zone = Dynamique (2 AZ différentes)
}
```
- **Nombre** : 2 subnets (configurable par variable)
- **Localisation** : 2 zones de disponibilité différentes
- **Attribution IP publique** : Désactivée

### NAT Gateway et Elastic IP
```hcl
aws_eip.nat_gateway (count = var.enable_nat_gateway ? 2 : 0)
aws_nat_gateway.main (count = var.enable_nat_gateway ? 2 : 0) {
  allocation_id = aws_eip.nat_gateway[index].id
  subnet_id     = aws_subnet.public[index].id
}
```
- **Nombre** : Créées uniquement si `enable_nat_gateway = true`
- **Placement** : Une par subnet public
- **Rôle** : Permet aux instances dans les subnets privés d'accéder à Internet

### Route Tables

#### Route Table Publique
```hcl
aws_route_table.public {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
```
Route tous les trafics sortants via Internet Gateway.

#### Route Tables Privées
```hcl
aws_route_table.private (count = var.enable_nat_gateway ? 2 : 0) {
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[index].id
  }
}
```
Route tous les trafics sortants via NAT Gateway (une par AZ).

### Associations Route Table
- Subnets publics → Route Table publique
- Subnets privés → Route Tables privées (une par AZ)

### Groupes de sécurité

#### ALB Security Group
```hcl
aws_security_group.alb {
  Ingress : HTTP (80), HTTPS (443) depuis 0.0.0.0/0
  Egress : Tous les trafics autorisés
}
```

#### EC2 Security Group
```hcl
aws_security_group.ec2 {
  Ingress SSH (22) : depuis 0.0.0.0/0
  Ingress API Gateway (8080) : depuis ALB
  Ingress inter-EC2 (0-65535/TCP) : depuis le même SG
  Ingress ActiveMQ (61616) : depuis le même SG
  Ingress ActiveMQ Admin Console (8161) : depuis VPC CIDR
  Egress : Tous les trafics autorisés
}
```

### Data Source - Zones de disponibilité
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```
Récupère dynamiquement les AZ disponibles dans la région.

---

## Ressources EC2 (ec2.tf)

### Gestion des clés EC2

#### Génération de clé privée
```hcl
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```
Génère une clé RSA 4096 bits.

#### Création de la paire de clés AWS
```hcl
resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project_name}-ec2-key-2026-1"
  public_key = tls_private_key.ec2.public_key_openssh
}
```
Importe la clé publique dans AWS.

#### Sauvegarde locale de la clé privée
```hcl
resource "local_file" "ec2_private_key" {
  content         = tls_private_key.ec2.private_key_pem
  filename        = "${path.module}/${var.project_name}-ec2-key-2026-1.pem"
  file_permission = "0600"
}
```
Sauvegarde la clé privée localement avec permissions restreintes.

### Data Source - Amazon Linux 2
```hcl
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```
Récupère l'AMI Amazon Linux 2 la plus récente.

### Data Source - IAM Role
```hcl
data "aws_iam_role" "ec2_instance_role" {
  name = "LabRole"
}
```
Référence le rôle IAM existant `LabRole` (fourni par AWS Academy).

### Instances EC2 principales

#### 1. Eureka Server
```hcl
resource "aws_instance" "eureka_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.ec2_key.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  
  user_data = base64encode(templatefile(...))
  tags = { Name = "ecommerce-eureka-server" }
}
```
- **Type** : t3.medium
- **Localisation** : Subnet privé (AZ 1)
- **Rôle** : Service de découverte (Eureka)
- **Port** : 8761
- **Health Check** : /actuator/health

#### 2. Product Service
```hcl
resource "aws_instance" "product_service" {
  ...
  user_data = ...
  depends_on = [aws_instance.eureka_server, aws_instance.activemq]
  tags = { Name = "ecommerce-product-service" }
}
```
- **Type** : t3.medium
- **Localisation** : Subnet privé (AZ 1)
- **Dépendance** : Eureka + ActiveMQ
- **Port** : 8081
- **Variables d'environnement** : Adresse IP privée d'Eureka, URL ActiveMQ

#### 3. Cart Service
```hcl
resource "aws_instance" "cart_service" {
  ...
  user_data = ...
  depends_on = [aws_instance.eureka_server, aws_instance.activemq]
  tags = { Name = "ecommerce-cart-service" }
}
```
- **Type** : t3.medium
- **Localisation** : Subnet privé (AZ 1)
- **Dépendance** : Eureka + ActiveMQ
- **Port** : 8082
- **Variables d'environnement** : Adresse IP privée d'Eureka, URL ActiveMQ

#### 4. API Gateway
```hcl
resource "aws_instance" "api_gateway" {
  ...
  user_data = ...
  depends_on = [aws_instance.eureka_server, aws_instance.product_service, aws_instance.cart_service]
  tags = { Name = "ecommerce-api-gateway" }
}
```
- **Type** : t3.medium
- **Localisation** : Subnet privé (AZ 1)
- **Dépendance** : Eureka + Product + Cart
- **Port** : 8080
- **Rôle** : Point d'entrée principal de l'API

#### 5. ActiveMQ
```hcl
resource "aws_instance" "activemq" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.ec2_key.key_name
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  
  user_data = file("${path.module}/user-data-activemq.sh")
  tags = { Name = "ecommerce-activemq" }
}
```
- **Type** : t3.medium
- **Localisation** : Subnet privé (AZ 1)
- **IP Publique** : Non associée
- **Port** : 61616 (JMS), 8161 (Admin console)
- **Rôle** : Message broker pour la communication asynchrone

### Configuration des instances via User Data

#### Eureka Server (user-data-eureka.sh)
```bash
yum install -y docker curl
systemctl enable docker && systemctl start docker

docker pull ${eureka_image}
docker run -d \
  --name eureka-server \
  --restart unless-stopped \
  -p 8761:8761 \
  -e EUREKA_CLIENT_REGISTER_WITH_EUREKA=false \
  -e EUREKA_CLIENT_FETCH_REGISTRY=false \
  -e SERVER_PORT=8761 \
  ${eureka_image}

# Vérification du démarrage (jusqu'à 30 tentatives)
```
- Installe Docker
- Pull l'image Eureka
- Lance le conteneur avec configuration Docker
- Valide que Eureka est en bon état

#### Microservices (user-data-service.sh)
```bash
yum install -y docker curl
systemctl enable docker && systemctl start docker

# Attendre que Eureka soit disponible
for i in {1..30}; do
  if curl -sf http://${eureka_server}:8761/eureka/apps > /dev/null; then
    break
  fi
  sleep 2
done

docker pull ${service_image}
docker run -d \
  --name ${service_name} \
  --restart unless-stopped \
  -p ${port}:${port} \
  -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://${eureka_server}:8761/eureka/ \
  -e SPRING_ACTIVEMQ_BROKER_URL=${activemq_broker_url} \
  ${service_image}
```
- Installe Docker
- Attend la disponibilité d'Eureka
- Pull l'image de service
- Lance le conteneur avec configuration Eureka et ActiveMQ

---

## Application Load Balancer (alb.tf)

### ALB Principal
```hcl
resource "aws_lb" "main" {
  name               = "ecommerce-alb-1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  enable_deletion_protection = false
}
```
- **Type** : Application Load Balancer (Layer 7)
- **Accès** : Public (accessible depuis Internet)
- **Subnets** : Déployé dans les 2 subnets publics (multi-AZ)

### Target Groups

#### API Gateway Target Group
```hcl
resource "aws_lb_target_group" "api_gateway" {
  name        = "ecommerce-api-gateway-tg-1"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/actuator/health"
    matcher             = "200"
  }
}
```

#### Product Service Target Group
```hcl
resource "aws_lb_target_group" "product_service" {
  name        = "ecommerce-product-service-tg-1"
  port        = 8081
  protocol    = "HTTP"
  # ... identique avec port 8081
}
```

#### Cart Service Target Group
```hcl
resource "aws_lb_target_group" "cart_service" {
  name        = "ecommerce-cart-service-tg-1"
  port        = 8082
  protocol    = "HTTP"
  # ... identique avec port 8082
}
```

**Health Checks communs** :
- **Chemin** : `/actuator/health` (Spring Boot Actuator)
- **Intervalle** : 30 secondes
- **Timeout** : 5 secondes
- **Seuils** : 3 vérifications OK/KO consécutives

### Listeners

#### Listener Principal (Port 80)
```hcl
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}
```
Redirige le trafic HTTP sur le port 80 vers API Gateway (port 8080).

#### Listener Product Service (Port 8081)
```hcl
resource "aws_lb_listener" "product_service" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8081
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.product_service.arn
  }
}
```
Redirige le trafic sur port 8081 vers Product Service.

#### Listener Cart Service (Port 8082)
```hcl
resource "aws_lb_listener" "cart_service" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8082
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cart_service.arn
  }
}
```
Redirige le trafic sur port 8082 vers Cart Service.

---

## Auto-Scaling (autoscaling.tf)

### Launch Templates

#### Template Product Service
```hcl
resource "aws_launch_template" "product" {
  name_prefix   = "ecommerce-product-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ec2_key.key_name
  
  user_data = base64encode(templatefile(...))
}
```

#### Template Cart Service
```hcl
resource "aws_launch_template" "cart" {
  name_prefix   = "ecommerce-cart-"
  # ... identique pour cart
}
```

#### Template API Gateway
```hcl
resource "aws_launch_template" "gateway" {
  name_prefix   = "ecommerce-gateway-"
  # ... identique pour gateway
}
```

### Auto Scaling Groups

#### ASG Product Service
```hcl
resource "aws_autoscaling_group" "product" {
  desired_capacity     = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = aws_subnet.private[*].id
  
  launch_template {
    id      = aws_launch_template.product.id
    version = "$Latest"
  }
  
  target_group_arns = [aws_lb_target_group.product_service.arn]
  health_check_type = "ELB"
}
```

#### ASG Cart Service
```hcl
resource "aws_autoscaling_group" "cart" {
  # ... identique pour cart
  target_group_arns = [aws_lb_target_group.cart_service.arn]
}
```

#### ASG API Gateway
```hcl
resource "aws_autoscaling_group" "gateway" {
  # ... identique pour gateway
  target_group_arns = [aws_lb_target_group.api_gateway.arn]
}
```

**Configuration commune** :
- **Capacité désirée** : 1 instance
- **Min/Max** : 1 à 3 instances
- **Subnets** : Tous les subnets privés (multi-AZ)
- **Health Check** : Basé sur ALB

---

## IAM et CloudWatch (iam.tf)

### CloudWatch Log Group
```hcl
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/ecommerce-2026-1"
  retention_in_days = var.log_retention_days  # 7 jours par défaut
}
```
Groupe de logs centralisé pour toutes les tâches ECS.

### IAM Roles
- **Utilisation** : Rôle existant `LabRole` (AWS Academy)
- **Accès** : Récupéré via data source
- **Fonctionnalité** : Permissions pour EC2 d'accéder aux services AWS

---

## Outputs (outputs.tf)

### Outputs ALB
```hcl
output "alb_dns_name"
output "alb_url"
```
DNS du load balancer et URL complète pour accéder à l'API.

### Outputs EC2 Instances
```hcl
output "ec2_eureka_server_private_ip"
output "ec2_eureka_server_instance_id"
output "ec2_product_service_private_ip"
output "ec2_product_service_instance_id"
output "ec2_cart_service_private_ip"
output "ec2_cart_service_instance_id"
output "ec2_api_gateway_private_ip"
output "ec2_api_gateway_instance_id"
```
Adresses IP privées et IDs des instances EC2.

### Outputs Sécurité
```hcl
output "ec2_key_pair_name"
output "ec2_key_pair_path"
output "ec2_security_group_id"
```
Informations sur les clés EC2 et groupes de sécurité.

### Outputs Réseau
```hcl
output "vpc_id"
```
ID du VPC créé.

---

## Déploiement

### Initialisation
```bash
terraform init
```
Initialise le répertoire de travail Terraform.

### Validation
```bash
terraform validate
terraform plan
```
Valide la configuration et génère un plan d'exécution.

### Déploiement
```bash
terraform apply
```
Crée toutes les ressources définies.

### Destruction
```bash
terraform destroy
```
Supprime toutes les ressources créées (attention : irréversible).

---

## Considérations d'exploitation

### Architecture
- **Haute disponibilité** : Multi-AZ pour ALB et subnets privés
- **Scaling** : Auto Scaling Groups configurés pour chaque service
- **Service Discovery** : Eureka pour la découverte dynamique des services
- **Messaging** : ActiveMQ pour la communication asynchrone

### Sécurité
- **Isolation réseau** : Subnets publics et privés
- **Contrôle d'accès** : Security groups restrictifs par service
- **Clés SSH** : Générées et stockées localement
- **Logs** : CloudWatch pour l'audit et la surveillance

### Monitoring
- **Health Checks** : ALB vérifie /actuator/health
- **Logs** : Centralisés dans CloudWatch
- **Outputs** : Fournissent tous les IDs et IPs pour monitoring externe

---

## Limitations et notes

- **Backend d'état** : Actuellement local (peut être migré vers S3)
- **Images Docker** : Utilisent des tags `:latest` (à adapter pour production)
- **SSH access** : Ouvert depuis 0.0.0.0/0 (à restreindre en production)
- **Clés privées** : Stockées localement (gérer avec prudence)
- **Prix** : NAT Gateway et instances t3.medium entraînent des coûts
