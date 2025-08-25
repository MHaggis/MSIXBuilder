using System;
using System.Diagnostics;
using System.IO;

namespace HaagerWrapper
{
    class Program
    {
        static void Main(string[] args)
        {
            try
            {
                string currentDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
                string psScript = Path.Combine(currentDir, "Haager.ps1");
                
                if (!File.Exists(psScript))
                {
                    Console.WriteLine("PowerShell script not found: " + psScript);
                    Console.WriteLine("Press any key to exit...");
                    Console.ReadKey();
                    return;
                }
                
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-ExecutionPolicy Bypass -File \"" + psScript + "\"";
                psi.UseShellExecute = false;
                psi.CreateNoWindow = false;
                
                Process process = Process.Start(psi);
                process.WaitForExit();
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error launching PowerShell script: " + ex.Message);
                Console.WriteLine("Press any key to exit...");
                Console.ReadKey();
            }
        }
    }
}