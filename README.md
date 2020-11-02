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
terraform plan --var "name=<name to use>" --var "docker_image=<docker image in dockerhub>"
terraform apply --var "name=<name to use>" --var "docker_image=<docker image in dockerhub>"
```

Once this has been created then check the Web App logs and the Container Instance logs to see if they were able to retreive the secret. This can be done using the portal by navigating to the resource group created by the Terraform.

# Go Application: Updates
The Go app uses the new ManagedIdentityCredential method to retrieve the azidentity credential and then the AzureIdentityCredentialAdapter to assign the credential to convert it to an authorizer that is compatible with the Azure SDK for Go V1 implementation.

Note by default, the NewManagedIdentityCredential method will look for an environment variable named AZURE_CLIENT_ID if one is not set. See the implementation here: https://github.com/Azure/azure-sdk-for-go/blob/master/sdk/azidentity/managed_identity_credential.go#L57

```
cred, err := azidentity.NewManagedIdentityCredential(clientID, nil)

authorizer := azidext.NewAzureIdentityCredentialAdapter(
		cred,
		azcore.AuthenticationPolicyOptions{
			Options: azcore.TokenRequestOptions{
				Scopes: []string{"https://vault.azure.net"}}}) // Keyvault scope

```

For more information, look at a similar example here: https://github.com/Azure/azure-sdk-for-go/blob/master/sdk/samples/azidentity/SDKV1Adapter/example_SDKV1_test.go#L77


# New Version
```
# Make code change
# Rebuild Docker app
docker build --rm -t <image name>:<new version> .
docker push <image name>:<new version>
terraform apply --var "docker_image=<image name>:<new version>" --var "name=<name>" --auto-approve
```