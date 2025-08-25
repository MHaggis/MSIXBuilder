using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace MSIXBuilderGUI
{
    /// <summary>
    /// Main form for the MSIXBuilder GUI application.
    /// Provides a user-friendly interface for creating MSIX packages with embedded test applications.
    /// Supports both C# and PowerShell payloads with various complexity levels for security testing.
    /// </summary>
    public partial class MainForm : Form
    {
        // UI Controls for package configuration
        private TextBox packageNameTextBox;
        private TextBox publisherTextBox;
        private TextBox outputPathTextBox;
        private RadioButton csharpRadio;
        private RadioButton powershellRadio;
        private RadioButton bothRadio;
        private CheckBox telemetryModeCheckBox;
        private CheckBox generateDetectionLogsCheckBox;
        private CheckBox skipDownloadsCheckBox;

        
        // UI Controls for status and actions
        private Label statusLabel;
        private ProgressBar progressBar;
        private Button validateButton;
        private Button createButton;
        private Button installCertButton;

        public MainForm()
        {
            InitializeComponent();
            SetDefaultValues();
        }

        private void InitializeComponent()
        {
            this.SuspendLayout();

            // Form properties
            this.Text = "MSIXBuilder";
            this.Size = new Size(800, 750);
            this.MinimumSize = new Size(750, 650);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = SystemColors.Control;

            // Header
            var headerPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 90, // Taller header for better spacing
                BackColor = Color.FromArgb(0, 120, 215) // Windows blue
            };

            var titleLabel = new Label
            {
                Text = "MSIXBuilder",
                Font = new Font("Segoe UI", 18, FontStyle.Bold),
                ForeColor = Color.White,
                Location = new Point(20, 15),
                AutoSize = true
            };

            var subtitleLabel = new Label
            {
                Text = "MSIX Package Creator",
                Font = new Font("Segoe UI", 10),
                ForeColor = Color.White,
                Location = new Point(20, 45),
                AutoSize = true
            };

            headerPanel.Controls.AddRange(new Control[] { titleLabel, subtitleLabel });

            // Main content panel
            var mainPanel = new Panel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(20),
                AutoScroll = true
            };

            int yPos = 30; // More spacing from header

            // Basic Configuration Group
            var basicGroupBox = CreateGroupBox("📋 Basic Configuration", ref yPos);
            
            packageNameTextBox = CreateTextBox("Package Name:", "e.g., SecurityTestApp", basicGroupBox, ref yPos);
            publisherTextBox = CreateTextBox("Publisher:", "e.g., RedTeam, SecurityResearch", basicGroupBox, ref yPos);
            
            var outputPanel = new Panel { Location = new Point(10, yPos), Size = new Size(520, 50) };
            var outputLabel = new Label { Text = "Output Directory:", Location = new Point(0, 0), Size = new Size(120, 23), Font = new Font("Segoe UI", 9, FontStyle.Bold) };
            outputPathTextBox = new TextBox { Location = new Point(0, 25), Size = new Size(420, 23), PlaceholderText = "C:\\MSIXBuild" };
            var browseButton = new Button { Text = "Browse", Location = new Point(430, 25), Size = new Size(80, 23) };
            browseButton.Click += BrowseButton_Click;
            outputPanel.Controls.AddRange(new Control[] { outputLabel, outputPathTextBox, browseButton });
            basicGroupBox.Controls.Add(outputPanel);
            yPos += 60;

            basicGroupBox.Height = yPos + 30; // More space in the group box
            mainPanel.Controls.Add(basicGroupBox);
            yPos += 50; // More space between groups

            // Application Type Group
            var appTypeGroupBox = CreateGroupBox("🎛️ Application Type", ref yPos);
            
            var appTypeLabel = new Label { Text = "Choose which type of test application to create", Location = new Point(10, 25), Size = new Size(400, 20), ForeColor = SystemColors.GrayText };
            appTypeGroupBox.Controls.Add(appTypeLabel);
            
            csharpRadio = new RadioButton { Text = "C# Application", Location = new Point(10, 50), Size = new Size(500, 20), Checked = true };
            var csharpDesc = new Label { Text = "Compiled .NET executable with advanced capabilities", Location = new Point(30, 70), Size = new Size(450, 15), Font = new Font("Segoe UI", 8), ForeColor = SystemColors.GrayText };
            
            powershellRadio = new RadioButton { Text = "PowerShell Application", Location = new Point(10, 95), Size = new Size(500, 20) };
            var psDesc = new Label { Text = "PowerShell script with C# wrapper for MSIX compatibility", Location = new Point(30, 115), Size = new Size(450, 15), Font = new Font("Segoe UI", 8), ForeColor = SystemColors.GrayText };
            
            bothRadio = new RadioButton { Text = "Both (Recommended)", Location = new Point(10, 140), Size = new Size(500, 20) };
            var bothDesc = new Label { Text = "Creates both types for comprehensive testing", Location = new Point(30, 160), Size = new Size(450, 15), Font = new Font("Segoe UI", 8), ForeColor = SystemColors.GrayText };

            appTypeGroupBox.Controls.AddRange(new Control[] { appTypeLabel, csharpRadio, csharpDesc, powershellRadio, psDesc, bothRadio, bothDesc });
            appTypeGroupBox.Height = 190;
            mainPanel.Controls.Add(appTypeGroupBox);
            yPos += 200;

            // Advanced Options Group
            var advancedGroupBox = CreateGroupBox("🔍 Advanced Options", ref yPos);
            
            telemetryModeCheckBox = new CheckBox { Text = "Enable Telemetry Mode", Location = new Point(10, 25), Size = new Size(500, 20) };
            var telemetryDesc = new Label { Text = "Comprehensive logging and detection point analysis", Location = new Point(30, 45), Size = new Size(450, 15), Font = new Font("Segoe UI", 8), ForeColor = SystemColors.GrayText };
            
            generateDetectionLogsCheckBox = new CheckBox { Text = "Generate Detection Logs", Location = new Point(10, 70), Size = new Size(500, 20) };
            var detectionDesc = new Label { Text = "Create JSON logs and YARA rules for defenders", Location = new Point(30, 90), Size = new Size(450, 15), Font = new Font("Segoe UI", 8), ForeColor = SystemColors.GrayText };
            
            skipDownloadsCheckBox = new CheckBox { Text = "Skip Automatic Downloads", Location = new Point(10, 115), Size = new Size(500, 20) };
            var skipDesc = new Label { Text = "Skip downloading missing dependencies (manual installation required)", Location = new Point(30, 135), Size = new Size(450, 15), Font = new Font("Segoe UI", 8), ForeColor = SystemColors.GrayText };

            advancedGroupBox.Controls.AddRange(new Control[] { telemetryModeCheckBox, telemetryDesc, generateDetectionLogsCheckBox, detectionDesc, skipDownloadsCheckBox, skipDesc });
            advancedGroupBox.Height = 165;
            mainPanel.Controls.Add(advancedGroupBox);
            yPos += 175;



            // Templates Group
            var templatesGroupBox = CreateGroupBox("📁 Quick Templates", ref yPos);
            
            var templatesLabel = new Label { Text = "Pre-configured scenarios for common testing needs", Location = new Point(10, 25), Size = new Size(400, 20), ForeColor = SystemColors.GrayText };
            
            var redTeamButton = new Button { Text = "🔴 Red Team Test", Location = new Point(10, 50), Size = new Size(120, 30) };
            var blueTeamButton = new Button { Text = "🔵 Blue Team Test", Location = new Point(140, 50), Size = new Size(120, 30) };
            var researchButton = new Button { Text = "🟢 Research", Location = new Point(270, 50), Size = new Size(120, 30) };
            var detectionButton = new Button { Text = "🟡 Detection Eng.", Location = new Point(400, 50), Size = new Size(120, 30) };

            redTeamButton.Click += (s, e) => ApplyTemplate("RedTeam", "RedTeamSecTest", "Both", true, true);
            blueTeamButton.Click += (s, e) => ApplyTemplate("BlueTeam", "DetectionValidation", "Both", true, true);
            researchButton.Click += (s, e) => ApplyTemplate("SecurityResearch", "MSIXResearch", "CSharp", false, false);
            detectionButton.Click += (s, e) => ApplyTemplate("DetectionEngineering", "DetectionTest", "Both", true, true);

            templatesGroupBox.Controls.AddRange(new Control[] { templatesLabel, redTeamButton, blueTeamButton, researchButton, detectionButton });
            templatesGroupBox.Height = 95;
            mainPanel.Controls.Add(templatesGroupBox);

            // Footer panel
            var footerPanel = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 90, // Taller footer for better button spacing
                BackColor = SystemColors.ControlLight
            };

            statusLabel = new Label
            {
                Text = "Ready to create MSIX package",
                Location = new Point(20, 15),
                Size = new Size(400, 20),
                Font = new Font("Segoe UI", 9)
            };

            progressBar = new ProgressBar
            {
                Location = new Point(20, 40),
                Size = new Size(400, 20),
                Visible = false
            };

            validateButton = new Button
            {
                Text = "Validate",
                Location = new Point(580, 15),
                Size = new Size(80, 30)
            };
            validateButton.Click += ValidateButton_Click;

            createButton = new Button
            {
                Text = "Create Package",
                Location = new Point(670, 15),
                Size = new Size(100, 30),
                BackColor = Color.FromArgb(0, 120, 215),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat
            };
            createButton.Click += CreateButton_Click;

            var logButton = new Button
            {
                Text = "View Logs",
                Location = new Point(450, 50),
                Size = new Size(80, 25),
                BackColor = SystemColors.Control,
                ForeColor = SystemColors.ControlText
            };
            logButton.Click += (s, e) => {
                var logPath = Path.Combine(Path.GetTempPath(), "MSIXBuilder", "gui.log");
                if (File.Exists(logPath))
                {
                    try
                    {
                        Process.Start("notepad.exe", logPath);
                    }
                    catch
                    {
                        MessageBox.Show($"Could not open log file. Location: {logPath}", "Log File", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                }
                else
                {
                    MessageBox.Show($"Log file not found at: {logPath}", "Log File", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            };

            // Install Certificate button (initially hidden)
            installCertButton = new Button
            {
                Text = "Install Certificate",
                Location = new Point(450, 15),
                Size = new Size(120, 30),
                BackColor = Color.FromArgb(0, 150, 0), // Green color
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Visible = false // Hidden until package is created
            };
            installCertButton.FlatAppearance.BorderSize = 0;
            installCertButton.Click += InstallCertButton_Click;

            footerPanel.Controls.AddRange(new Control[] { statusLabel, progressBar, validateButton, createButton, logButton, installCertButton });

            // Add all panels to form
            this.Controls.AddRange(new Control[] { headerPanel, mainPanel, footerPanel });

            this.ResumeLayout(false);
        }

        private GroupBox CreateGroupBox(string title, ref int yPos)
        {
            var groupBox = new GroupBox
            {
                Text = title,
                Location = new Point(0, yPos),
                Size = new Size(540, 100), // Will be adjusted later
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                ForeColor = Color.FromArgb(0, 120, 215)
            };
            return groupBox;
        }

        private TextBox CreateTextBox(string label, string placeholder, GroupBox parent, ref int yPos)
        {
            var labelControl = new Label
            {
                Text = label,
                Location = new Point(10, yPos),
                Size = new Size(120, 23),
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            
            var textBox = new TextBox
            {
                Location = new Point(10, yPos + 25),
                Size = new Size(500, 23),
                PlaceholderText = placeholder
            };

            parent.Controls.AddRange(new Control[] { labelControl, textBox });
            yPos += 50;
            return textBox;
        }

        private void SetDefaultValues()
        {
            outputPathTextBox.Text = @"C:\MSIXBuild";
            packageNameTextBox.Text = "SecurityTestApp";
            publisherTextBox.Text = "SecurityResearch";
        }

        private void BrowseButton_Click(object sender, EventArgs e)
        {
            using (var dialog = new FolderBrowserDialog())
            {
                dialog.Description = "Select output directory";
                dialog.ShowNewFolderButton = true;
                if (dialog.ShowDialog() == DialogResult.OK)
                {
                    outputPathTextBox.Text = dialog.SelectedPath;
                }
            }
        }

        /// <summary>
        /// Applies a pre-configured template for common testing scenarios.
        /// Templates help users quickly set up packages for specific use cases like red team, blue team, etc.
        /// </summary>
        private void ApplyTemplate(string publisher, string packageName, string appType, bool telemetry, bool generateLogs)
        {
            publisherTextBox.Text = publisher;
            packageNameTextBox.Text = packageName;

            csharpRadio.Checked = appType == "CSharp";
            powershellRadio.Checked = appType == "PowerShell";
            bothRadio.Checked = appType == "Both";

            telemetryModeCheckBox.Checked = telemetry;
            generateDetectionLogsCheckBox.Checked = generateLogs;



            UpdateStatus($"Applied {publisher} template configuration");
        }

        private async void ValidateButton_Click(object sender, EventArgs e)
        {
            validateButton.Enabled = false;
            UpdateStatus("Validating configuration...");

            try
            {
                await Task.Delay(1000); // Simulate validation

                var errors = ValidateConfiguration();
                if (errors.Count > 0)
                {
                    MessageBox.Show("Configuration Issues:\n\n" + string.Join("\n", errors), 
                                    "Validation Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    UpdateStatus("Configuration validation failed");
                }
                else
                {
                    UpdateStatus("Configuration is valid ✓");
                }
            }
            finally
            {
                validateButton.Enabled = true;
            }
        }

        private async void CreateButton_Click(object sender, EventArgs e)
        {
            var errors = ValidateConfiguration();
            if (errors.Count > 0)
            {
                MessageBox.Show("Please fix the following issues:\n\n" + string.Join("\n", errors),
                                "Configuration Issues", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            createButton.Enabled = false;
            validateButton.Enabled = false;
            progressBar.Visible = true;
            installCertButton.Visible = false; // Hide until success

            try
            {
                await CreateMSIXPackage();
            }
            finally
            {
                createButton.Enabled = true;
                validateButton.Enabled = true;
                progressBar.Visible = false;
            }
        }

        private List<string> ValidateConfiguration()
        {
            var errors = new List<string>();

            if (string.IsNullOrWhiteSpace(packageNameTextBox.Text))
                errors.Add("• Package Name is required");

            if (string.IsNullOrWhiteSpace(publisherTextBox.Text))
                errors.Add("• Publisher is required");

            if (string.IsNullOrWhiteSpace(outputPathTextBox.Text))
                errors.Add("• Output Directory is required");

            if (!csharpRadio.Checked && !powershellRadio.Checked && !bothRadio.Checked)
                errors.Add("• Application Type must be selected");

            return errors;
        }

        /// <summary>
        /// Main method for creating MSIX packages.
        /// Orchestrates the entire process: validation, script execution, progress tracking, and certificate installation.
        /// Runs the PowerShell script in non-interactive mode to prevent GUI hanging.
        /// </summary>
        private async Task CreateMSIXPackage()
        {
            UpdateStatus("Creating MSIX package...");
            progressBar.Value = 0;

            try
            {
                var appType = GetSelectedAppType();

                
                UpdateStatus("Building PowerShell command...");
                progressBar.Value = 10;
                
                var command = BuildPowerShellCommand(appType);

                UpdateStatus("Executing PowerShell script...");
                progressBar.Value = 20;

                // Start a progress update task to show we're still working
                var progressUpdateCancellation = new CancellationTokenSource();
                var progressTask = UpdateProgressPeriodically(progressUpdateCancellation.Token);

                var result = await ExecutePowerShellScript(command);
                
                // Stop the progress updates
                progressUpdateCancellation.Cancel();
                progressBar.Value = 100;

                if (result.Success)
                {
                    UpdateStatus("MSIX package created successfully! ✓");

                    // Show the Install Certificate button
                    installCertButton.Visible = true;

                    var dialogResult = MessageBox.Show(
                        $"MSIX package created successfully!\n\nOutput: {outputPathTextBox.Text}\n\nWould you like to open the output folder?",
                        "Success!", MessageBoxButtons.YesNo, MessageBoxIcon.Information);

                    if (dialogResult == DialogResult.Yes)
                    {
                        Process.Start("explorer.exe", outputPathTextBox.Text);
                    }
                }
                else
                {
                    // Hide the Install Certificate button on failure
                    installCertButton.Visible = false;
                    UpdateStatus("Failed to create MSIX package ✗");
                    MessageBox.Show($"Failed to create MSIX package:\n\n{result.ErrorMessage}",
                                    "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
            catch (Exception ex)
            {
                UpdateStatus("Error occurred during package creation ✗");
                MessageBox.Show($"An unexpected error occurred:\n\n{ex.Message}",
                                "Unexpected Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private string GetSelectedAppType()
        {
            if (csharpRadio.Checked) return "CSharp";
            if (powershellRadio.Checked) return "PowerShell";
            if (bothRadio.Checked) return "Both";
            return "Both";
        }

        /// <summary>
        /// Extracts the embedded PowerShell script from the executable resources.
        /// This ensures the script is always available even if the external file is missing.
        /// </summary>
        private string GetEmbeddedScriptPath()
        {
            try
            {
                // Extract the embedded PowerShell script to a temporary location
                var assembly = Assembly.GetExecutingAssembly();
                var resourceName = "MSIXBuilderGUI.Create-MSIXPackage.ps1";
                
                // Debug: List all embedded resources
                var resourceNames = assembly.GetManifestResourceNames();
                UpdateStatus($"Available resources: {string.Join(", ", resourceNames)}");
                
                using (var stream = assembly.GetManifestResourceStream(resourceName))
                {
                    if (stream == null)
                    {
                        UpdateStatus($"Embedded resource '{resourceName}' not found. Available: {string.Join(", ", resourceNames)}");
                        throw new FileNotFoundException($"Embedded resource '{resourceName}' not found.");
                    }

                    // Create temp file
                    var tempPath = Path.Combine(Path.GetTempPath(), "MSIXBuilder", "Create-MSIXPackage.ps1");
                    var tempDir = Path.GetDirectoryName(tempPath);
                    
                    if (!Directory.Exists(tempDir))
                    {
                        Directory.CreateDirectory(tempDir);
                    }

                    // Extract the script with proper encoding
                    using (var reader = new StreamReader(stream, System.Text.Encoding.UTF8))
                    using (var writer = new StreamWriter(tempPath, false, System.Text.Encoding.UTF8))
                    {
                        var content = reader.ReadToEnd();
                        
                        // Basic validation - check if it looks like a PowerShell script
                        if (!content.Contains("#Requires -RunAsAdministrator") || !content.Contains("param("))
                        {
                            UpdateStatus($"Warning: Extracted script doesn't look like valid PowerShell. Length: {content.Length}");
                            UpdateStatus($"First 200 chars: {content.Substring(0, Math.Min(200, content.Length))}");
                        }
                        
                        writer.Write(content);
                    }

                    UpdateStatus($"Extracted embedded script to: {tempPath}");
                    return tempPath;
                }
            }
            catch (Exception ex)
            {
                // Fallback to external file search
                UpdateStatus($"Failed to extract embedded script: {ex.Message}");
                UpdateStatus("Attempting to find external script...");
                return FindExternalScript();
            }
        }

        private string FindExternalScript()
        {
            // Try multiple possible locations for the PowerShell script
            var possiblePaths = new[]
            {
                Path.Combine(Application.StartupPath, "Create-MSIXPackage.ps1"), // Same directory as GUI
                Path.Combine(Application.StartupPath, "..", "Create-MSIXPackage.ps1"), // Parent directory  
                Path.Combine(Application.StartupPath, "..", "..", "Create-MSIXPackage.ps1"), // Two levels up (from GUI/MSIXBuilderGUI to root)
                Path.Combine(Application.StartupPath, "..", "..", "..", "Create-MSIXPackage.ps1"), // Three levels up
                Path.Combine(Environment.CurrentDirectory, "Create-MSIXPackage.ps1"), // Current working directory
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "MSIXBuilder", "Create-MSIXPackage.ps1"), // Desktop
                @"C:\tools\MSIXBuilder\Create-MSIXPackage.ps1", // Common tools path
            };

            UpdateStatus("Searching for PowerShell script in common locations...");

            foreach (var path in possiblePaths)
            {
                try
                {
                    var fullPath = Path.GetFullPath(path);
                    UpdateStatus($"Checking: {fullPath}");
                    
                    if (File.Exists(fullPath))
                    {
                        UpdateStatus($"Found script at: {fullPath}");
                        return fullPath;
                    }
                }
                catch (Exception ex)
                {
                    UpdateStatus($"Error checking path {path}: {ex.Message}");
                }
            }

            // Let user browse for it
            UpdateStatus("Script not found in common locations. Please browse for it.");
            MessageBox.Show("Cannot find Create-MSIXPackage.ps1 script automatically.\n\nThis script should be in the root directory of the MSIXBuilder project.\n\nPlease select the script location manually.", 
                           "Script Not Found", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            
            using (var dialog = new OpenFileDialog())
            {
                dialog.Title = "Select Create-MSIXPackage.ps1";
                dialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*";
                dialog.FileName = "Create-MSIXPackage.ps1";
                dialog.InitialDirectory = Path.GetDirectoryName(Application.StartupPath);
                
                if (dialog.ShowDialog() == DialogResult.OK)
                {
                    UpdateStatus($"User selected script: {dialog.FileName}");
                    return dialog.FileName;
                }
                else
                {
                    throw new FileNotFoundException("PowerShell script not found and user cancelled selection.");
                }
            }
        }

        private string BuildPowerShellCommand(string appType)
        {
            // Get the PowerShell script (embedded or external)
            string scriptPath = GetEmbeddedScriptPath();

            // Update status to show which script we're using
            UpdateStatus($"Using PowerShell script: {scriptPath}");

            // Validate the script exists and is readable
            if (!File.Exists(scriptPath))
            {
                throw new FileNotFoundException($"PowerShell script not found at: {scriptPath}");
            }

            // Test if the script is valid PowerShell by checking its content
            try
            {
                var scriptContent = File.ReadAllText(scriptPath);
                if (scriptContent.Length < 100 || !scriptContent.Contains("param("))
                {
                    throw new InvalidOperationException($"Script appears to be corrupted or invalid. Length: {scriptContent.Length}");
                }
                UpdateStatus($"Script validation passed. Size: {scriptContent.Length} characters");
            }
            catch (Exception ex)
            {
                UpdateStatus($"Script validation failed: {ex.Message}");
                throw;
            }

            var command = $"& '{scriptPath}' -PackageName '{packageNameTextBox.Text}' -Publisher '{publisherTextBox.Text}' -OutputPath '{outputPathTextBox.Text}' -AppType '{appType}'";

            if (telemetryModeCheckBox.Checked)
                command += " -TelemetryMode";

            if (generateDetectionLogsCheckBox.Checked)
                command += " -GenerateDetectionLogs";

            if (skipDownloadsCheckBox.Checked)
                command += " -SkipDownloads";

            UpdateStatus($"PowerShell command: {command.Substring(0, Math.Min(100, command.Length))}...");
            return command;
        }

        /// <summary>
        /// Executes the PowerShell script with comprehensive error handling and logging.
        /// Uses non-interactive execution to prevent GUI hanging on user prompts.
        /// Includes timeout protection and detailed progress monitoring.
        /// </summary>
        private async Task<(bool Success, string ErrorMessage)> ExecutePowerShellScript(string command)
        {
            try
            {
                // Check if we need to run as administrator
                bool needsElevation = !IsRunningAsAdministrator();
                UpdateStatus($"Administrator privileges needed: {needsElevation}");
                
                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-ExecutionPolicy Bypass -Command \"{command}\"",
                    UseShellExecute = needsElevation, // Must be true for elevation
                    RedirectStandardOutput = !needsElevation, // Can't redirect when using shell execute
                    RedirectStandardError = !needsElevation,
                    CreateNoWindow = !needsElevation,
                    WindowStyle = needsElevation ? ProcessWindowStyle.Normal : ProcessWindowStyle.Hidden
                };

                if (needsElevation)
                {
                    processStartInfo.Verb = "runas";
                    UpdateStatus("Requesting administrator privileges...");
                }
                else
                {
                    UpdateStatus("Starting PowerShell process without elevation...");
                }

                UpdateStatus($"Starting process: {processStartInfo.FileName} {processStartInfo.Arguments.Substring(0, Math.Min(100, processStartInfo.Arguments.Length))}...");

                using var process = Process.Start(processStartInfo);
                if (process == null)
                    return (false, "Failed to start PowerShell process");

                UpdateStatus($"Process started with PID: {process.Id}");

                if (needsElevation)
                {
                    // When elevated, we can't capture output, so just wait for completion with timeout
                    UpdateStatus("Waiting for elevated PowerShell process to complete...");
                    
                    // Add timeout for elevated processes
                    var timeoutTask = Task.Delay(TimeSpan.FromMinutes(10)); // 10 minute timeout
                    var processTask = process.WaitForExitAsync();
                    
                    var completedTask = await Task.WhenAny(processTask, timeoutTask);
                    
                    if (completedTask == timeoutTask)
                    {
                        UpdateStatus("PowerShell process timed out - attempting to kill...");
                        try
                        {
                            process.Kill();
                        }
                        catch { }
                        return (false, "PowerShell process timed out after 10 minutes");
                    }
                    
                    UpdateStatus($"Elevated process completed with exit code: {process.ExitCode}");
                    
                    if (process.ExitCode == 0)
                        return (true, "PowerShell script completed successfully");
                    else
                        return (false, $"PowerShell script exited with error code {process.ExitCode}");
                }
                else
                {
                    // When not elevated, capture output with timeout
                    UpdateStatus("Capturing output from non-elevated PowerShell process...");
                    
                    var outputTask = process.StandardOutput.ReadToEndAsync();
                    var errorTask = process.StandardError.ReadToEndAsync();
                    var processTask = process.WaitForExitAsync();
                    var timeoutTask = Task.Delay(TimeSpan.FromMinutes(10)); // 10 minute timeout

                    var completedTask = await Task.WhenAny(Task.WhenAll(outputTask, errorTask, processTask), timeoutTask);
                    
                    if (completedTask == timeoutTask)
                    {
                        UpdateStatus("PowerShell process timed out - attempting to kill...");
                        try
                        {
                            process.Kill();
                        }
                        catch { }
                        return (false, "PowerShell process timed out after 10 minutes");
                    }

                    var output = await outputTask;
                    var error = await errorTask;

                    UpdateStatus($"Process completed with exit code: {process.ExitCode}");
                    UpdateStatus($"Output length: {output?.Length ?? 0}, Error length: {error?.Length ?? 0}");

                    if (process.ExitCode == 0)
                        return (true, output ?? "Process completed successfully");
                    else
                        return (false, error?.Length > 0 ? error : "PowerShell script exited with error code " + process.ExitCode);
                }
            }
            catch (Exception ex)
            {
                UpdateStatus($"Exception in ExecutePowerShellScript: {ex.Message}");
                return (false, ex.Message);
            }
        }

        private bool IsRunningAsAdministrator()
        {
            try
            {
                var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
                var principal = new System.Security.Principal.WindowsPrincipal(identity);
                return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        private async Task UpdateProgressPeriodically(CancellationToken cancellationToken)
        {
            try
            {
                int currentProgress = 20;
                while (!cancellationToken.IsCancellationRequested && currentProgress < 90)
                {
                    await Task.Delay(2000, cancellationToken); // Update every 2 seconds
                    if (!cancellationToken.IsCancellationRequested)
                    {
                        currentProgress = Math.Min(90, currentProgress + 5);
                        progressBar.Value = currentProgress;
                        UpdateStatus($"PowerShell script running... ({currentProgress}%)");
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // Expected when cancelled
            }
        }

        private void InstallCertButton_Click(object sender, EventArgs e)
        {
            try
            {
                var certPath = Path.Combine(outputPathTextBox.Text, "Output", "TestCert.cer");
                
                if (!File.Exists(certPath))
                {
                    MessageBox.Show($"Certificate file not found at: {certPath}", "Certificate Not Found", 
                                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }

                UpdateStatus("Installing certificate...");

                // Use PowerShell to install the certificate
                var psCommand = $"Import-Certificate -FilePath '{certPath}' -CertStoreLocation 'Cert:\\LocalMachine\\TrustedPeople'";
                
                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-ExecutionPolicy Bypass -Command \"{psCommand}\"",
                    UseShellExecute = true,
                    Verb = "runas", // Request admin privileges
                    WindowStyle = ProcessWindowStyle.Hidden
                };

                var process = Process.Start(processStartInfo);
                process.WaitForExit();

                if (process.ExitCode == 0)
                {
                    UpdateStatus("Certificate installed successfully! ✓");
                    MessageBox.Show("Certificate installed successfully!\n\nYou can now install the MSIX package using:\nAdd-AppPackage -Path [path-to-msix]", 
                                    "Certificate Installed", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
                else
                {
                    UpdateStatus("Certificate installation failed ✗");
                    MessageBox.Show($"Certificate installation failed.\n\nYou can manually install it using:\nImport-Certificate -FilePath '{certPath}' -CertStoreLocation 'Cert:\\LocalMachine\\TrustedPeople'", 
                                    "Installation Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
            }
            catch (Exception ex)
            {
                UpdateStatus("Certificate installation error ✗");
                MessageBox.Show($"Error installing certificate: {ex.Message}\n\nPlease install manually or run as administrator.", 
                                "Installation Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void UpdateStatus(string message)
        {
            if (InvokeRequired)
            {
                Invoke(new Action<string>(UpdateStatus), message);
                return;
            }
            statusLabel.Text = message;
            
            // Also write to debug output for troubleshooting
            System.Diagnostics.Debug.WriteLine($"[MSIXBuilder] {DateTime.Now:HH:mm:ss} - {message}");
            
            // Write to log file for troubleshooting
            try
            {
                var logPath = Path.Combine(Path.GetTempPath(), "MSIXBuilder", "gui.log");
                var logDir = Path.GetDirectoryName(logPath);
                if (!Directory.Exists(logDir))
                {
                    Directory.CreateDirectory(logDir);
                }
                File.AppendAllText(logPath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} - {message}{Environment.NewLine}");
            }
            catch
            {
                // Ignore logging errors
            }
        }
    }
} 