# Azure GO MSI
This is an example repo for debugging the differences between using MSI for getting an Azure KV secret in a Go based Docker Azure Web App and a Go based Azure Container Instance. Web Apps do not seem to properly support MSI for this use case while the Container Instance does.

This repo has a simple Go app that will lookup a secret from a KV instance using a user managed identity. The Terraform will create a resource group, key vault, managed identity and access policies, and a test instace for both an Azure Web App and Azure Container Instance to see if they can retreive the secret using that managed identity.

# Docker Image
To test this first build and publish the `Dockerfile`:
```
docker build --rm -t <dockerhub repo>/<container name>:<version> .
docker push <dockerhub repo>/<container name>:<version>
```

Make sure that this is a publicly accessible container image so that it can be pulled into the Web App and Container Instance

# Terraform
The Terraform requires 2 inputs, a name for the deployment, and the docker image that is in dockerhub. To run the Terraform do the following:
```
terraform init
terraform play --var "name=<name to use>" --var "docker_image=<docker image in dockerhub>"
terraform apply --var "name=<name to use>" --var "docker_image=<docker image in dockerhub>"
```

Once this has been created then check the Web App logs and the Container Instance logs to see if they were able to retreive the secret. This can be done using the portal by navigating to the resource group created by the Terraform.

# Go Application
The Go app can use 2 possible methods for using the MSI to get the KV secret.

Method 1:
```
msiKeyConfig := &auth.MSIConfig{
		Resource: strings.TrimSuffix(azure.PublicCloud.KeyVaultEndpoint, "/"),
		ClientID: clientID,
	}

authorizer, err := msiKeyConfig.Authorizer()
```

Method 2:
```
authorizer, err := auth.NewAuthorizerFromEnvironment()
```

The authorizer method can be changed in the `NewKeyVaultClient` method by changing which authorizer method to use, either `getMSIAuthorizer` or `getAuthorizerFromEnv`.

When testing a new auth method the docker container must be rebuilt and pushed with a new version and then that version must be deployed to Azure using the Terraform and the "docker_image" variable.

# New Version
```
# Make code change
# Rebuild Docker app
docker build --rm -t <image name>:<new version> .
docker push <image name>:<new version>
terraform apply --var "docker_image=<image name>:<new version>" --var "name=<name>" --auto-approve
```