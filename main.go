package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/Azure/azure-sdk-for-go/profiles/latest/keyvault/keyvault"
	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/go-autorest/autorest"
	"github.com/Azure/go-autorest/autorest/azure"
	"github.com/Azure/go-autorest/autorest/azure/auth"
	"github.com/jongio/azidext/go/azidext"
)

func main() {
	vaultName, ok := os.LookupEnv("KEYVAULT_VAULT_NAME")
	if !ok {
		log.Fatal("KEYVAULT_VAULT_NAME must be set.")
	}

	secretName, ok := os.LookupEnv("KEYVAULT_SECRET_NAME")
	if !ok {
		log.Fatal("KEYVAULT_SECRET_NAME must be set.")
	}

	clientID, ok := os.LookupEnv("MSI_USER_ASSIGNED_CLIENTID")
	if !ok {
		log.Fatal("MSI_USER_ASSIGNED_CLIENTID must be set.")
	}

	keyClient, err := NewKeyVaultClient(vaultName, clientID)
	if err != nil {
		log.Fatal(err)
	}

	secret, err := keyClient.GetSecret(secretName)
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("Retrieved secret '%s' from keyvault using MSI", secret)
}

// KeyVault holds the information for a keyvault instance
type KeyVault struct {
	client   *keyvault.BaseClient
	vaultURL string
}

// NewKeyVaultClient creates a new keyvault client
func NewKeyVaultClient(vaultName, clientID string) (*KeyVault, error) {
	// SDK v1
	// authorizer, err := getMSIAuthorizer(clientID)
	// authorizer, err := getAuthorizerFromEnv()

	// instantiate a new ManagedIdentityCredential as specified in the example
	cred, err := azidentity.NewManagedIdentityCredential(clientID, nil)

	if err != nil {
		fmt.Printf("Error: %v", err)
	}

	fmt.Printf("Got MI Creds")
	// call azidext.NewAzureIdentityCredentialAdapter with the azidentity credential and necessary scope
	// NOTE: Scopes define the set of resources and permissions that the credential will have assigned to it.
	// To read more about scopes, see: https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent
	authorizer := azidext.NewAzureIdentityCredentialAdapter(
		cred,
		azcore.AuthenticationPolicyOptions{
			Options: azcore.TokenRequestOptions{
				Scopes: []string{"https://vault.azure.net"}}}) // Keyvault scope

	if err != nil {
		fmt.Printf("Error: %v", err)
	}
	fmt.Printf("Got KeyVault Authorizer")

	keyClient := keyvault.New()
	keyClient.Authorizer = authorizer

	k := &KeyVault{
		vaultURL: fmt.Sprintf("https://%s.%s", vaultName, azure.PublicCloud.KeyVaultDNSSuffix),
		client:   &keyClient,
	}

	return k, nil
}

// SDK v1
func getMSIAuthorizer(clientID string) (autorest.Authorizer, error) {
	msiKeyConfig := &auth.MSIConfig{
		Resource: strings.TrimSuffix(azure.PublicCloud.KeyVaultEndpoint, "/"),
		ClientID: clientID,
	}

	return msiKeyConfig.Authorizer()
}

// SDK v1
func getAuthorizerFromEnv() (autorest.Authorizer, error) {
	return auth.NewAuthorizerFromEnvironment()
}

// GetSecret retrieves a secret from keyvault
func (k *KeyVault) GetSecret(keyName string) (string, error) {
	ctx := context.Background()

	keyBundle, err := k.client.GetSecret(ctx, k.vaultURL, keyName, "")
	if err != nil {
		return "", err
	}

	return *keyBundle.Value, nil
}
