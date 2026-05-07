# 🚀 Guide rapide - Relancer le déploiement

## Déploiement initial (DÉJÀ FAIT ✅)

L'infrastructure a été **complètement déployée sur AWS** avec Terraform.

### Résultat:
```
✅ VPC + Subnets
✅ Load Balancer (ALB)
✅ 4 instances EC2 (Eureka, API Gateway, Product Service, Cart Service)
✅ NAT Gateways
✅ Security Groups
✅ S3 Bucket
✅ CloudWatch Logs
```

---

## Pour relancer/mettre à jour le déploiement

### 1️⃣ Préparation
```bash
cd terraform

# Mettre à jour Terraform (optionnel)
terraform upgrade

# Vérifier l'état actuel
terraform show
terraform output
```

### 2️⃣ Valider les changements
```bash
# Voir ce qui va être modifié
terraform plan

# Voir les différences en détail
terraform plan -detailed-exitcode
```

### 3️⃣ Appliquer les changements
```bash
# Option 1: Avec confirmation
terraform apply

# Option 2: Automatiquement (sans confirmation)
terraform apply -auto-approve

# Option 3: Depuis un plan sauvegardé
terraform plan -out=tfplan
terraform apply tfplan
```

### 4️⃣ Uploader les JAR files

#### Sous Windows (PowerShell):
```powershell
.\upload-jars.ps1
```

#### Sous Linux/Mac (Bash):
```bash
chmod +x upload-jars.sh
./upload-jars.sh
```

#### Manuel:
```bash
BUCKET=$(terraform output -raw s3_jar_bucket_name)

aws s3 cp ../eureka-server/target/eureka-server-0.0.1-SNAPSHOT.jar.original \
  s3://$BUCKET/eureka-server-0.0.1-SNAPSHOT.jar --region us-east-1

aws s3 cp ../product-service/target/product-service-0.0.1-SNAPSHOT.jar.original \
  s3://$BUCKET/product-service-0.0.1-SNAPSHOT.jar --region us-east-1

aws s3 cp ../cart-service/target/cart-service-0.0.1-SNAPSHOT.jar.original \
  s3://$BUCKET/cart-service-0.0.1-SNAPSHOT.jar --region us-east-1

aws s3 cp ../api-gateway/target/api-gateway-0.0.1-SNAPSHOT.jar.original \
  s3://$BUCKET/api-gateway-0.0.1-SNAPSHOT.jar --region us-east-1
```

### 5️⃣ Vérifier le déploiement
```bash
# Voir les IPs et DNS
terraform output

# Tester le load balancer
ALB_URL=$(terraform output -raw alb_url)
curl $ALB_URL/actuator/health

# Vérifier les instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=ecommerce" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PrivateIpAddress]' \
  --region us-east-1
```

---

## Commandes utiles

### Afficher les outputs
```bash
terraform output                    # Tous les outputs
terraform output alb_url           # Un output spécifique
terraform output -json             # Format JSON
```

### Voir l'état
```bash
terraform state list               # Lister les ressources
terraform state show <resource>    # Détails d'une ressource
terraform state rm <resource>      # Supprimer du state
```

### Replanifier
```bash
terraform plan -refresh-only       # Synchroniser avec AWS
terraform apply -refresh-only      # Appliquer la synchronisation
```

### Détruire l'infrastructure
```bash
terraform destroy                  # Avec confirmation
terraform destroy -auto-approve    # Sans confirmation
```

---

## Modifier les variables

### Changer la taille des instances
```bash
# Éditer terraform.tfvars ou passer en argument
terraform apply -var='instance_type=t3.large'
```

### Changements courants
```bash
# Désactiver les NAT Gateways (économiser de l'argent)
terraform apply -var='enable_nat_gateway=false'

# Changer le région
terraform apply -var='aws_region=eu-west-1'

# Changer le nombre de répliques (pour ECS, si utilisé)
terraform apply -var='desired_count=2'
```

---

## Troubleshooting rapide

### "No configuration files"
```bash
# Assurez-vous d'être dans le répertoire terraform
cd terraform
terraform plan
```

### "Error reading S3 Bucket"
```bash
# Les permissions AWS Academy peuvent être restrictives
# Vérifiez que le bucket a bien été créé
aws s3 ls | grep ecommerce-jars

# Si le bucket existe déjà, vous pouvez l'utiliser
terraform apply -var="s3_bucket_name=existing-bucket-name"
```

### "Instances still starting"
```bash
# Attendre 2-3 minutes que les instances téléchargent les JAR
# Vérifier les logs
aws logs tail /ecs/ecommerce --follow

# Vérifier la santé du load balancer
aws elbv2 describe-target-health \
  --target-group-arn <arn-from-output> \
  --region us-east-1
```

### "Health Check Failed"
```bash
# Vérifier que les JAR files sont bien dans S3
aws s3 ls s3://$(terraform output -raw s3_jar_bucket_name)

# Vérifier les logs des instances via CloudWatch
# CloudWatch > Logs > /ecs/ecommerce
```

---

## Monitoring

### CloudWatch Logs
```bash
# Voir les logs en temps réel
aws logs tail /ecs/ecommerce --follow

# Filtrer les erreurs
aws logs filter-log-events \
  --log-group-name /ecs/ecommerce \
  --filter-pattern "ERROR"
```

### Load Balancer Health
```bash
aws elbv2 describe-load-balancers \
  --names ecommerce-alb \
  --region us-east-1

aws elbv2 describe-target-health \
  --target-group-arn <arn> \
  --region us-east-1
```

### Instances Status
```bash
aws ec2 describe-instance-status \
  --filters "Name=tag:Project,Values=ecommerce" \
  --region us-east-1
```

---

## Sauvegarde et Restauration

### Sauvegarder l'état
```bash
# L'état est déjà sauvegardé dans terraform.tfstate
# Faire un backup supplémentaire
cp terraform.tfstate terraform.tfstate.$(date +%Y%m%d-%H%M%S).backup
```

### Restaurer un état
```bash
# Si vous avez un backup
cp terraform.tfstate.backup terraform.tfstate
terraform refresh
```

