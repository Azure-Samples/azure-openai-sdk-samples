# Azure OpenAI on your data and function calling

A sample demonstrating the integration of [Azure OpenAI On Your Data](https://learn.microsoft.com/azure/ai-services/openai/concepts/use-your-data?tabs=ai-search) with [Chat Completions Functions](https://learn.microsoft.com/azure/ai-services/openai/how-to/function-calling) in the form of a project planning assistant. Building on the general chat experience, users can ask for details from their provided data (e.g. "Who do I file UI bugs against?" or "Which versions of our project are most-used by customers?") for improved conversation context. When the user is ready to create work items, the assistant can make one or several calls to GitHub and includes relevant information like the project area and assignee for the item. See [this three minute video](https://youtu.be/qOwmwr0wN6o) for an end-to-end walkthrough of the project in action.

## Prerequisites

* A GitHub repository with permissions to create a personal access token (PAT). See [Configure GitHub resources](#configure-github-resources) for more details
* An Azure account with access enabled for Azure OpenAI services, [more details](#azure-account-requirements)

## Project layout

The project is provided with the option of engaging via CLI or web app frontend, found in [azure-openai-cli](./azure-openai-cli/) and [azure-openai-webapp](./azure-openai-webapp/), respectively. The [azure-openai-bin](./azure-openai-bin) directory contains the "backend" API logic for the Azure OpenAI and GitHub calls.

## Azure account requirements

**IMPORTANT:** In order to deploy and run this example, you'll need:

* **Azure account**. If you're new to Azure, [get an Azure account for free](https://azure.microsoft.com/free/cognitive-search/) and you'll get some free Azure credits to get started.
* **Azure subscription with access enabled for the Azure OpenAI service**. You can request access with [this form](https://aka.ms/oaiapply).
* **Azure account permissions**:
  * Your Azure account must have `Microsoft.Authorization/roleAssignments/write` permissions, such as [Role Based Access Control Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator-preview), [User Access Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator), or [Owner](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#owner). If you don't have subscription-level permissions, you must be granted [RBAC](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator-preview) for an existing resource group and [deploy to that existing group](#deploy-with-existing-azure-resources).
  * Your Azure account also needs `Microsoft.Resources/deployments/write` permissions on the subscription level.

## Azure deployment

### Cost estimation

Pricing varies per region and usage, so it isn't possible to predict exact costs for your usage.
However, you can try the [Azure pricing calculator](https://azure.com/e/8ffbe5b1919c4c72aed89b022294df76) for the resources below.

* Azure App Service: Basic Tier with 1 CPU core, 1.75 GB RAM. Pricing per hour. [Pricing](https://azure.microsoft.com/pricing/details/app-service/linux/)
* Azure OpenAI: Standard tier, ChatGPT and Ada models. Pricing per 1K tokens used, and at least 1K tokens are used per question. [Pricing](https://azure.microsoft.com/en-us/pricing/details/cognitive-services/openai-service/)
* Azure AI Search: Standard tier, 1 replica, free level of semantic search. Pricing per hour.[Pricing](https://azure.microsoft.com/pricing/details/search/)
* Azure Blob Storage: Standard tier with ZRS (Zone-redundant storage). Pricing per storage and read operations. [Pricing](https://azure.microsoft.com/pricing/details/storage/blobs/)

### Project setup

#### Local environment

Prerequisites:

* [Azure Developer CLI](https://aka.ms/azure-dev/install)
* [Git](https://git-scm.com/downloads)
* [Powershell 7+ (pwsh)](https://github.com/powershell/powershell) - For Windows users only.
  * **Important**: Ensure you can run `pwsh.exe` from a PowerShell terminal. If this fails, you likely need to upgrade PowerShell.
* A GitHub repository you have admin access to.
  * You'll need a [personal access token (PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) with necessary read/write permissions for making the respective actions requested by the copilot (e.g. reading the list of existing Issues, creating a new Issue, etc.)

Configure the workspace:

1. Clone the project and navigate to its location in the terminal
1. Run `azd auth login`

#### Deploy from scratch

If you don't have any pre-existing Azure services and want to start from a fresh deployment. (If you already have existing Azure resources you want to re-use, follow the steps below in [deploy with existing Azure resources](#deploy-with-existing-azure-resources))

> [!IMPORTANT]
> Be aware that the resources created by this command will incur immediate costs, primarily from the AI Search resource. These resources may accrue costs even if you interrupt the command before it is fully executed. You can run `azd down` or delete the resources manually to avoid unnecessary spending.

1. Run `azd up` - This will provision Azure resources and deploy this sample to those resources, including building the search index based on the files found in the `./data` folder.
    * You will be prompted to select a location for the resources, this needs to be a location with OpenAI resource support (which is currently a short list). That location list is based on the [OpenAI model availability table](https://learn.microsoft.com/azure/cognitive-services/openai/concepts/models#model-summary-table-and-region-availability) and may become outdated as availability changes.
1. Create a Search Index

> [!NOTE]
> As of this writing, az cli does not support creating a Search Index or Indexer. An automated workaround is [in-progress]( https://github.com/Azure-Samples/azure-openai-sdk-samples/issues/4), until then the Index can be manually set up as follows.

  * WIP - Azure Portal steps
	1. Go to resource group
	2. Select Search service
	3. Select "Add Index (JSON)"
		a. Paste JSON from MyData\oyd-index.json and click Save
		b. Save index name to AZURE_SEARCH_INDEX
	4. Add data source
		a. Select storage account
	5. Select "Add Indexer (JSON)"
		a. Paste JSON from MyData\oyd-indexer.json and click Save
    b. click "Run" 

#### Deploy with existing Azure resources

If you already have existing Azure resources you want to re-use, you can do so by setting `azd` environment values.

* Run `azd env set AZURE_RESOURCE_GROUP {Name of existing resource group}`
* Run `azd env set AZURE_LOCATION {Location of existing resource group}`
* Run `azd env set AZURE_OPENAI_SERVICE {Name of existing OpenAI service}`
* Run `azd env set AZURE_OPENAI_RESOURCE_GROUP {Name of existing resource group that OpenAI service is provisioned to}`
* Run `azd env set AZURE_OPENAI_CHATGPT_DEPLOYMENT {Name of existing ChatGPT deployment}`. Only needed if your ChatGPT deployment is not the default 'chat'.

* `AZURE_SEARCH_ENDPOINT`
* `AZURE_SEARCH_INDEX`
* `AZURE_SEARCH_KEY`
* `AZURE_SEARCH_DEPLOYMENT`

#### Existing Azure AI Search resource

* `AZURE_OPENAI_ENDPOINT`
* `AZURE_OPENAI_KEY`

* Run `azd env set AZURE_SEARCH_SERVICE {Name of existing Azure AI Search service}`
* Run `azd env set AZURE_SEARCH_SERVICE_RESOURCE_GROUP {Name of existing resource group with ACS service}`
* If that resource group is in a different location than the one you'll pick for the `azd up` step,
  then run `azd env set AZURE_SEARCH_SERVICE_LOCATION {Location of existing service}`
* If the search service's SKU is not standard, then run `azd env set AZURE_SEARCH_SERVICE_SKU {Name of SKU}`. The free tier won't work as it doesn't support managed identity. If your existing search service is using the free tier, you will need to deploy a new service since [search SKUs cannot be changed](https://learn.microsoft.com/azure/search/search-sku-tier#tier-upgrade-or-downgrade). ([See other possible SKU values](https://learn.microsoft.com/azure/templates/microsoft.search/searchservices?pivots=deployment-language-bicep#sku))
* If you have an existing index that is set up with all the expected fields, then run `azd env set AZURE_SEARCH_INDEX {Name of existing index}`. Otherwise, see the steps above in "Create a Search Index" to create a new index.

#### Configure GitHub resources

* Run `azd env set GITHUB_PAT {your GitHub PAT}`
* Run `azd env set GITHUB_USER {GitHub username}`
* Run `azd env set GITHUB_REPO_NAME {GitHub repository name}`
* [Optional] Run `azd env set GITHUB_ORG_NAME` if your repository is in a GitHub Org, e.g. `https://api.github.com/repos/{org}/{repo}`

### Deploying again

If you've only changed the backend/frontend code, then you don't need to re-provision the Azure resources. You can just run:

```azd deploy```

If you've changed the infrastructure files (`infra` folder or `azure.yaml`), then you'll need to re-provision the Azure resources. You can do that by running:

```azd up```

## Build and run

From the parent directory:
`dotnet run --project azure-openai-cli`
