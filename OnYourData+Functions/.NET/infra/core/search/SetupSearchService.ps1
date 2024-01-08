param(
    [string] [Parameter(Mandatory=$true)] $searchServiceName,
    [string] [Parameter(Mandatory=$true)] $dataSourceContainerName,
    [string] [Parameter(Mandatory=$true)] $dataSourceType
)

$ErrorActionPreference = 'Stop'

$apiversion = '2020-06-30'
$token = Get-AzAccessToken -ResourceUrl https://search.azure.com | select -expand Token
$headers = @{ 'Authorization' = "Bearer $token"; 'Content-Type' = 'application/json'; }
$uri = "https://$searchServiceName.search.windows.net"
$indexDefinition = $null
#$dataSourceDefinition = $null
$indexerDefinition = $null
$DeploymentScriptOutputs = @{}

# Create data source, index, and indexer definitions
switch ($dataSourceType)
{
    "azureblob" {
        $indexDefinition = @{
            'name' = 'oyd-index'
            'defaultScoringProfile' = $null
            'fields' = @(
                @{ 'name' = 'content'; 'type' = 'Edm.String'; 'searchable' = $true; 'filterable' = $false; 'retrievable' = $true; 'sortable' = $false; 'facetable' = $false; 'key' = $false; 'indexAnalyzer' = $null; 'searchAnalyzer' = $null; 'analyzer' = $null; 'normalizer' = $null; 'dimensions' = $null; 'vectorSearchProfile' = $null; 'synonymMaps' = @() },
                @{ 'name' = 'filepath'; 'type' = 'Edm.String'; 'searchable' = $false; 'filterable' = $false; 'retrievable' = $true; 'sortable' = $false; 'facetable' = $false; 'key' = $false; 'indexAnalyzer' = $null; 'searchAnalyzer' = $null; 'analyzer' = $null; 'normalizer' = $null; 'dimensions' = $null; 'vectorSearchProfile' = $null; 'synonymMaps' = @() },
                @{ 'name' = 'title'; 'type' = 'Edm.String'; 'searchable' = $true; 'filterable' = $false; 'retrievable' = $true; 'sortable' = $false; 'facetable' = $false; 'key' = $false; 'indexAnalyzer' = $null; 'searchAnalyzer' = $null; 'analyzer' = $null; 'normalizer' = $null; 'dimensions' = $null; 'vectorSearchProfile' = $null; 'synonymMaps' = @() },
                @{ 'name' = 'url'; 'type' = 'Edm.String'; 'searchable' = $false; 'filterable' = $false; 'retrievable' = $true; 'sortable' = $false; 'facetable' = $false; 'key' = $false; 'indexAnalyzer' = $null; 'searchAnalyzer' = $null; 'analyzer' = $null; 'normalizer' = $null; 'dimensions' = $null; 'vectorSearchProfile' = $null; 'synonymMaps' = @() },
                @{ 'name' = 'id'; 'type' = 'Edm.String'; 'searchable' = $false; 'filterable' = $true; 'retrievable' = $true; 'sortable' = $true; 'facetable' = $false; 'key' = $true; 'indexAnalyzer' = $null; 'searchAnalyzer' = $null; 'analyzer' = $null; 'normalizer' = $null; 'dimensions' = $null; 'vectorSearchProfile' = $null; 'synonymMaps' = @() },
                @{ 'name' = 'chunk_id'; 'type' = 'Edm.String'; 'searchable' = $false; 'filterable' = $false; 'retrievable' = $true; 'sortable' = $false; 'facetable' = $false; 'key' = $false; 'indexAnalyzer' = $null; 'searchAnalyzer' = $null; 'analyzer' = $null; 'normalizer' = $null; 'dimensions' = $null; 'vectorSearchProfile' = $null; 'synonymMaps' = @() },
                @{ 'name' = 'last_updated'; 'type' = 'Edm.String'; 'searchable' = $false; 'filterable' = $false; 'retrievable' = $true; 'sortable' = $false; 'facetable' = $false; 'key' = $false; 'indexAnalyzer' = $null; 'searchAnalyzer' = $null; 'analyzer' = $null; 'normalizer' = $null; 'dimensions' = $null; 'vectorSearchProfile' = $null; 'synonymMaps' = @() }
            );
            'scoringProfiles' = @()
            'corsOptions' = $null
            'suggesters' = @()
            'analyzers' = @()
            'normalizers' = @()
            'tokenizers' = @()
            'tokenFilters' = @()
            'charFilters' = @()
            'encryptionKey' = $null
            'similarity' = @{
                '@odata.type' = '#Microsoft.Azure.Search.BM25Similarity'
                'k1' = $null
                'b' = $null
            }
            'semantic' = @{
                'defaultConfiguration' = $null
                'configurations' = @(
                    @{
                        'name' = 'default'
                        'prioritizedFields' = @{
                            'titleField' = @{
                                'fieldName' = 'title'
                            }
                            'prioritizedContentFields' = @(
                                @{
                                    'fieldName' = 'content'
                                }
                            )
                            'prioritizedKeywordsFields' = @()
                        }
                    }
                )
            }
            'vectorSearch' = $null
        }
        $indexerDefinition = @{
            'name' = 'oyd-indexer';
            'targetIndexName' = 'oyd-index';
            'dataSourceName' = 'oyd-blobcontainer';
            'parameters' = @{
                'configuration' = @{
                   'indexedFileNameExtensions' = '.md'
                }
            };
            'schedule' = 'null'; # 'null' means run once, requires manual runs for updated data
        }
        $DeploymentScriptOutputs['indexName'] = $indexDefinition['name']
    }
    default {
        throw "Unsupported data source type $dataSourceType"
    }
}

try {
    # https://learn.microsoft.com/rest/api/searchservice/create-index
    Invoke-WebRequest `
        -Method 'PUT' `
        -Uri "$uri/indexes/$($indexDefinition['name'])?api-version=$apiversion" `
        -Headers  $headers `
        -Body (ConvertTo-Json $indexDefinition)

    # https://learn.microsoft.com/rest/api/searchservice/create-indexer
    Invoke-WebRequest `
        -Method 'PUT' `
        -Uri "$uri/indexers/$($indexerDefinition['name'])?api-version=$apiversion" `
        -Headers $headers `
        -Body (ConvertTo-Json $indexerDefinition)
} catch {
    Write-Error $_.ErrorDetails.Message
    throw
}