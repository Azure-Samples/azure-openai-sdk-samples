namespace AzureOpenAISamples
{
    using System;
    using System.IO;

    // A temporary helper class to load environment variables from a local .env file.
    // Can be removed (or disabled) with the completion of the bicep onboarding.
    public static class EnvConfig
    {
        public static void Load(string filePath)
        {
            if (!File.Exists(filePath))
                return;

            foreach (var line in File.ReadAllLines(filePath))
            {
                var parts = line.Split(
                    '=',
                    StringSplitOptions.RemoveEmptyEntries);

                if (parts.Length != 2)
                    continue;

                // Console.WriteLine("Setting environment variable: " + parts[0] + " = " + parts[1]);
                Environment.SetEnvironmentVariable(parts[0], parts[1], EnvironmentVariableTarget.Process);
            }
        }
    }
}