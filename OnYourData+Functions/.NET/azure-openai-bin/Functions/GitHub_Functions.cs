using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;
using Octokit;

public record WorkItem(
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("body")] string? Body,
    [property: JsonPropertyName("assignee")] string? Assignee,
    [property: JsonPropertyName("labels")] string?[]? Labels
);

public class WorkItemList
{
    public IList<WorkItem>? workItems { get; set; }
}

    // Provides function definitions for actions that can be requested by chat
    // interactions. In this sample, we retrieve and create Issues in GitHub
    // using the Octokit library for GitHub API access.
    public static class GitHubFunctions
{
    private static string owner = Environment.GetEnvironmentVariable("GITHUB_USER")
        ?? throw new Exception("GITHUB_USER environment variable not set");
    private static string org = Environment.GetEnvironmentVariable("GITHUB_ORG_NAME")
        ?? throw new Exception("GITHUB_ORG_NAME environment variable not set");
    private static string repo = Environment.GetEnvironmentVariable("GITHUB_REPO_NAME")
        ?? throw new Exception("GITHUB_REPO_NAME environment variable not set");
    static string? githubPAT = Environment.GetEnvironmentVariable("GITHUB_PAT")
        ?? throw new Exception("GITHUB_PAT environment variable not set");

    // a shared client for all requests (temporary until Octokit is used for all requests)
    private static HttpClient sharedClient = new()
    {
        BaseAddress = new Uri($"https://api.github.com/repos/{org}/{repo}"),
    };

    /// <summary>
    /// Processes a raw JSON string and converts it into a NewIssue object.
    /// The JSON string is expected to be deserializable into a WorkItem object.
    /// If the deserialization fails, an exception is thrown.
    /// </summary>
    /// <param name="rawJson">The raw JSON string to process.</param>
    /// <returns>An Octokit NewIssue object created from the JSON string.</returns>
    public static NewIssue ProcessRawJsonToOctokitWorkItem(string rawJson)
    {
        var newWorkItem = JsonSerializer.Deserialize<WorkItem>(rawJson);
        if(newWorkItem == null)
        {
            throw new Exception("Failed to deserialize JSON");
        }

        NewIssue newIssue = new NewIssue(newWorkItem.Title)
        {
            Body = newWorkItem.Body,
        };
        foreach (var label in newWorkItem.Labels)
        {
            newIssue.Labels.Add(label);
        }
        return newIssue;
    }


    // Creates a new work item using the Octokit library.
    public static async Task CreateNewWorkItemOctokit(string rawArguments)
    {
        // The API will reject you if you don't provide a User-Agent header.
        var client = new GitHubClient(new Octokit.ProductHeaderValue("my-aoai-sample"));
        client.Credentials = new Credentials(githubPAT);

        var newIssue = ProcessRawJsonToOctokitWorkItem(rawArguments);

        // Create the new issue using the Octokit library.
        await client.Issue.Create(org, repo, newIssue);
    }

    // When a chat response contains an array of actions to take, it can provide them as a set
    // for us to process all at once rather than a step-wise execution
    // e.g. "Create three new issues" is provided in one payload instead of three back-to-back turns
    public static async Task CreateManyWorkItems(string rawArguments)
    {
        Console.WriteLine(rawArguments);
        WorkItemList json = JsonSerializer.Deserialize<WorkItemList>(rawArguments)
            ?? throw new Exception("Could not deserialize JSON");

        // The API will reject you if you don't provide a User-Agent header.
        sharedClient.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("my-aoai-sample", "1.0"));

        Console.WriteLine($"Creating {json?.workItems.Count} work items");
        foreach (var item in json.workItems)
        {
            // TODO refactor to use the Octokit library
            var request = new HttpRequestMessage(HttpMethod.Post, sharedClient.BaseAddress + "/issues");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", githubPAT);

            Console.WriteLine("Creating new work item:");
            Console.WriteLine($"Title: {item.Title}");
            Console.WriteLine($"Description: {item.Body}");
            Console.WriteLine("");

            request.Content = new StringContent(JsonSerializer.Serialize<WorkItem>(item));
            Console.WriteLine(request.Content);

            var response = await sharedClient.SendAsync(request);
            response.EnsureSuccessStatusCode();
            var jsonResponse = await response.Content.ReadAsStringAsync();
            Console.WriteLine($"{jsonResponse}\n");
        }
    }

    public static async Task ListAllIssuesAsync()
    {
        // The API will reject you if you don't provide a User-Agent header.
        var client = new GitHubClient(new Octokit.ProductHeaderValue("my-aoai-sample"));

        client.Credentials = new Credentials(githubPAT);

        var issues = await client.Issue.GetAllForRepository(org, repo);
        Console.WriteLine($"Found {issues.Count} issues:\n");
        foreach(var issue in issues)
        {
            Console.WriteLine($"Issue #{issue.Number}: {issue.Title}");
        }
    }
}
