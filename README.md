# Terraform Commands :

### Initialize Terraform
   ```
   terraform init
   ```

### Generate and View the Execution Plan:
   ```
   terraform plan
   ```

### Apply the Terraform plan
   ```
   terraform apply
   ```

### Access the Flask App in your browser
   Once deployed, your app should be accessible via the public IP of the ECS task on port 5000.
   ```
   http://<public-ip>:5000
   ```
   To find the IP: `AWS Console → ECS → Tasks → Click your running task → Configuration → Public IP`

### To destroy the infrastructure and remove all resources created by Terraform, run:
   ```
   terraform destroy
   ```

# Docker Commands :

### To create a Dockerfile
```
docker init
```

### To build docker image
```
docker build -t <image-name>:<tag> .
```

### To run dockerfile
#### Use `-d` flag to run container in detach mode
```
docker run -it -p 8000:8000 --name <container-name> <image-name>
```

### To open shell inside container (get inside container)
```
docker exec -it <container-name> bash
```