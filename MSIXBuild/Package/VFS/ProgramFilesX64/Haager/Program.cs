using System;
using System.IO;
using System.Management;
using System.Security.Principal;
using System.Diagnostics;
using System.Threading;

namespace HaagerApp
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("======================================");
            Console.WriteLine("    MSIX Security Test Application    ");
            Console.WriteLine("======================================");
            Console.WriteLine();
            
            DisplaySystemInfo();
            CheckDomainMembership();
            CreateTestFiles();
            CheckMSIXContainer();
            
            Console.WriteLine("Test completed successfully!");
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }
        
        static void DisplaySystemInfo()
        {
            Console.WriteLine("System Information:");
            Console.WriteLine("- Current User: " + Environment.UserName);
            Console.WriteLine("- Machine Name: " + Environment.MachineName);
            Console.WriteLine("- Current Directory: " + Directory.GetCurrentDirectory());
            Console.WriteLine("- Process ID: " + Process.GetCurrentProcess().Id);
            Console.WriteLine("- OS Version: " + Environment.OSVersion);
            Console.WriteLine("- CLR Version: " + Environment.Version);
            Console.WriteLine();
        }
        
        static void CheckDomainMembership()
        {
            try
            {
                string domain = GetDomainName();
                Console.WriteLine("Domain Check:");
                Console.WriteLine("- Domain: " + domain);
                
                if (domain.Equals("WORKGROUP", StringComparison.OrdinalIgnoreCase))
                {
                    Console.WriteLine("- Status: Workgroup computer (not domain-joined)");
                }
                else
                {
                    Console.WriteLine("- Status: Domain-joined computer");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("- Domain check failed: " + ex.Message);
            }
            Console.WriteLine();
        }
        
        static string GetDomainName()
        {
            try
            {
                using (ManagementObject mo = new ManagementObject("Win32_ComputerSystem.Name=\"" + Environment.MachineName + "\""))
                {
                    return mo["Domain"].ToString();
                }
            }
            catch
            {
                return Environment.UserDomainName;
            }
        }
        
        static void CreateTestFiles()
        {
            try
            {
                Console.WriteLine("File Operations:");
                
                string testDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "HaagerTest");
                Directory.CreateDirectory(testDir);
                Console.WriteLine("- Created directory: " + testDir);
                
                string testFile = Path.Combine(testDir, "test.txt");
                File.WriteAllText(testFile, 
                    "MSIX Security Test File" + Environment.NewLine +
                    "Package: Haager" + Environment.NewLine +
                    "Created: " + DateTime.Now + Environment.NewLine +
                    "User: " + Environment.UserName + Environment.NewLine +
                    "Machine: " + Environment.MachineName + Environment.NewLine);
                Console.WriteLine("- Created file: " + testFile);
                
                string psScript = Path.Combine(testDir, "test-script.ps1");
                File.WriteAllText(psScript, 
                    "# MSIX Test PowerShell Script" + Environment.NewLine +
                    "Write-Host \"PowerShell execution from MSIX container\"" + Environment.NewLine +
                    "Get-Process | Select-Object -First 5" + Environment.NewLine);
                Console.WriteLine("- Created script: " + psScript);
            }
            catch (Exception ex)
            {
                Console.WriteLine("- File operation failed: " + ex.Message);
            }
            Console.WriteLine();
        }
        
        static void CheckMSIXContainer()
        {
            Console.WriteLine("MSIX Container Information:");
            bool inContainer = IsRunningInMSIXContainer();
            Console.WriteLine("- Running in MSIX container: " + inContainer);
            Console.WriteLine("- Current working directory: " + Environment.CurrentDirectory);
            Console.WriteLine();
        }
        
        static bool IsRunningInMSIXContainer()
        {
            try
            {
                string currentDir = Environment.CurrentDirectory;
                return currentDir.Contains("WindowsApps") || currentDir.Contains("Program Files\\WindowsApps");
            }
            catch
            {
                return false;
            }
        }
    }
}