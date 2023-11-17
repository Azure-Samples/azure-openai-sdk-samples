using System.Text.Json;
using Azure;
using Azure.AI.OpenAI;
using static System.Environment;

public class PlanningCopilot
{
    // Azure OpenAI configuration
    static string? endpoint = GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT")
        ?? throw new Exception("Azure OpenAI endpoint not set");
    static string? key = GetEnvironmentVariable("AZURE_OPENAI_KEY")
        ?? throw new Exception("Azure OpenAI key not set");
    static string? deploymentName = GetEnvironmentVariable("AZURE_OPENAI_DEPLOYMENT")
        ?? throw new Exception("Deployment name not set");

    // Azure Cognitive Search configuration
    static string? searchEndpoint = GetEnvironmentVariable("AZURE_SEARCH_ENDPOINT")
        ?? throw new Exception("Search endpoint not set");
    static string? searchKey = GetEnvironmentVariable("AZURE_SEARCH_KEY")
        ?? throw new Exception("Search key not set");
    static string? searchIndexName = GetEnvironmentVariable("AZURE_SEARCH_INDEX")
        ?? throw new Exception("Search index not set");
    static string? searchDeploymentName = GetEnvironmentVariable("AZURE_SEARCH_DEPLOYMENT")
        ?? throw new Exception("Search deployment name not set");
    private OpenAIClient client;

    // The chat history for the current session. Keep in mind we aren't doing summarization
    // logic, long inputs and/or conversations with many turns can reach the max message length quickly.
    private List<ChatMessage> Messages = new()
    {
        new ChatMessage(ChatRole.System, "You can help plan work, including providing project-relevant details, as well as retrieve and create Issues on GitHub."),
    };

    private ChatCompletionsOptions GetOptions() => new ChatCompletionsOptions(messages: Messages)
    {

    };

    private ChatCompletionsOptions GetOptionsWithFunctions()
    {
        var options = GetOptions();

        // Adds a Function definition for creating a new work item in GitHub
        options.Functions.Add(
            new()
            {
                Name = "create_workitem",
                Description = "Creates a work item in GitHub.",
                Parameters = BinaryData.FromObjectAsJson(
                    new
                    {
                        Type = "object",
                        Properties = new
                        {
                            Title = new
                            {
                                Type = "string",
                                Description = "The title of the work item."
                            },
                            Body = new
                            {
                                Type = "string",
                                Description = "The description of the work item."
                            },
                            Labels = new
                            {
                                Type = "array",
                                Items = new
                                {
                                    Type = "string",
                                    Properties = new
                                    {
                                        Label = new
                                        {
                                            Type = "string",
                                            Description = "The name of the label."
                                        },
                                    }
                                }
                            }
                        },
                        Required = new[] { "Title" },
                    },
                    new JsonSerializerOptions() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }),
            });

        // Adds a Function definition for creating multiple new work items in GitHub
        options.Functions.Add(
            new()
            {
                Name = "create_workitems",
                Description = "Creates work items in GitHub.",
                Parameters = BinaryData.FromObjectAsJson(
                    new
                    {
                        Type = "object",
                        Properties = new
                        {
                            WorkItems = new
                            {
                                Type = "array",
                                Items = new
                                {
                                    Type = "object",
                                    Properties = new
                                    {
                                        Title = new
                                        {
                                            Type = "string",
                                            Description = "The title of the work item."
                                        },
                                        Body = new
                                        {
                                            Type = "string",
                                            Description = "The description of the work item."
                                        },
                                        Labels = new
                                        {
                                            Type = "array",
                                            Items = new
                                            {
                                                Type = "string",
                                                Properties = new
                                                {
                                                    Label = new
                                                    {
                                                        Type = "string",
                                                        Description = "The name of the label."
                                                    },
                                                }
                                            }
                                        }
                                    },
                                    Required = new[] { "Title" },
                                },
                            },
                        },
                        Required = new[] { "WorkItems" },
                    },
                    new JsonSerializerOptions() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }),
            });

        // Adds a Function definition for listing work items in GitHub
        options.Functions.Add(
            new()
            {
                Name = "list_workitems",
                Description = "Lists work items in GitHub.",
                Parameters = BinaryData.FromObjectAsJson(
                    new
                    {
                        Type = "object",
                        Properties = new
                        {
                            milestone = new
                            {
                                Type = "string",
                                Description = "The milestone of items to retrieve. If '*' is specified, issues with any milestone are retrieved. If 'none' is specified, only items with no milestone are retrieved."
                            },
                            state = new
                            {
                                Type = "string",
                                Description = "Indicates the state of the issues to return. Can be one of 'open', 'closed', or 'all'. Defaults to 'open'"
                            },
                        },
                    },
                    new JsonSerializerOptions() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }),
            }
        );

        // Adds a Function definition for getting information using Azure OpenAI on your data
        options.Functions.Add(
            new()
            {
                Name = "project-info-lookup",
                Description = "When a user asks for specifics on their project, like area owners or technical details, use this function to request additional information from their 'Azure OpenAI on your data' resource. Provide their question as the 'Topic' parameter.",
                Parameters = BinaryData.FromObjectAsJson(
                    new
                    {
                        Type = "object",
                        Properties = new
                        {
                            Topic = new
                            {
                                Type = "string",
                                Description = "The user's question about their project."
                            },
                        },
                        Required = new[] { "Topic" },
                    },
                    new JsonSerializerOptions() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }),
            }
        );
        return options;
    }

    private ChatCompletionsOptions GetOptionsWithExtensions()
    {
        var options = GetOptions();

        // Set up the "On Your Data" component, enabling this
        // sample's scenario of identifying the SME for a given topic
        options.AzureExtensionsOptions = new AzureChatExtensionsOptions()
        {
            Extensions =
            {
                new AzureCognitiveSearchChatExtensionConfiguration()
                {
                    SearchEndpoint = new Uri(searchEndpoint),
                    IndexName = searchIndexName,
                    SearchKey = new AzureKeyCredential(searchKey),
                }
            }
        };
        return options;
    }
    public PlanningCopilot()
    {
        client = new(new Uri(endpoint), new AzureKeyCredential(key));
    }

    public async Task SendMessage(string userInput)
    {
        Messages.Add(new ChatMessage(ChatRole.User, userInput));
        Response<ChatCompletions> response = client.GetChatCompletions(
            deploymentOrModelName: deploymentName,
            GetOptionsWithFunctions());
        Console.WriteLine(response.Value.Choices[0].Message);
        Console.WriteLine(response.Value.Choices[0].Message.Content);
        Console.WriteLine();

        // We send the Message history in our responses, for context. Since the Azure Search
        // deployment doesn't currently support FunctionCall properties, it will give an
        // error 'Additional properties are not allowed Status: 400 (model_error)' if we include
        // it. For this sample, we'll mitigate by excluding these messages from the history.
        if (response.Value.Choices[0].Message.FunctionCall == null)
        {
            Messages.Add(response.Value.Choices[0].Message);
        }

        #region ProcessFunctionCalls
        ChatChoice responseChoice = response.Value.Choices[0];
        if (responseChoice.FinishReason == CompletionsFinishReason.FunctionCall)
        {
            Console.WriteLine($"FunctionCall: {responseChoice.Message.FunctionCall.Name}");
            Console.WriteLine($"Arguments:\n{responseChoice.Message.FunctionCall.Arguments}");

            switch (responseChoice.Message.FunctionCall.Name)
            {
                case "create_workitem":
                    Console.WriteLine("Calling CreateNewWorkItemOctokit\n");
                    string rawArguments = responseChoice.Message.FunctionCall.Arguments;
                    Console.WriteLine(rawArguments);
                    await GitHubFunctions.CreateNewWorkItemOctokit(rawArguments);
                    break;

                case "create_workitems":
                    Console.WriteLine("Calling CreateManyNewWorkItems\n");
                    rawArguments = responseChoice.Message.FunctionCall.Arguments;
                    await GitHubFunctions.CreateManyWorkItems(rawArguments);
                    break;

                case "list_workitems":
                    Console.WriteLine("Calling ListAllIssuesAsync()\n");
                    await GitHubFunctions.ListAllIssuesAsync();
                    break;

                case "project-info-lookup":
                    Console.WriteLine("Calling Lookup\n");
                    response = client.GetChatCompletions(
                        deploymentOrModelName: searchDeploymentName,
                        GetOptionsWithExtensions());
                    Console.WriteLine(response.Value.Choices[0].Message.Content);
                    Console.WriteLine();
                    Messages.Add(new ChatMessage(ChatRole.Assistant, response.Value.Choices[0].Message.Content));
                    break;

                default:
                    Console.WriteLine($"Function not implemented: {responseChoice.Message.FunctionCall.Name}");
                    break;
            }
        }
        else
        {
            Console.WriteLine($"FinishReason: {responseChoice.FinishReason}");
        }
        #endregion
    }

    public void PrintChatHistory()
    {
        Console.WriteLine("\nPrinting all session messages:\n");
        foreach(var message in Messages)
        {
            Console.Write($"[{message.Role}]: ");
            if(message.Content != null)
                Console.WriteLine($"{message.Content}\n");
            if(message.FunctionCall != null)
            {
                Console.WriteLine($"\nFunctionCall: {message.FunctionCall.Name}");
                Console.WriteLine($"Arguments:\n{message.FunctionCall.Arguments}");
            }
        }
    }
}
