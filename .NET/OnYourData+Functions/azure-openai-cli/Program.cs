using AzureOpenAISamples;

class Program
{
    public static async Task Main()
    {
        var root = Directory.GetCurrentDirectory();
        var dotenv = Path.Combine(root, ".env");
        EnvConfig.Load(dotenv);

        Console.WriteLine("Type a message to send to the chat or press `ENTER` on an empty line to exit");

        var planningCopilot = new PlanningCopilot();
        while (true)
        {
            // Receives text from console input and send to chat
            Console.Write("\n> ");
            var text = Console.ReadLine();

            if (string.IsNullOrEmpty(text))
            {
                Console.WriteLine("Exiting...");
                planningCopilot.PrintChatHistory();
                break;
            }

            // Sends text to chat and receives a response
            await planningCopilot.SendMessage(text);
        }
    }
}
