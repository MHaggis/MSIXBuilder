# MSIXBuilder 🔥

**The ultimate MSIX package creator for security testing, red team exercises, and detection validation.**

[![Build Status](https://github.com/MHaggis/MSIXBuilder/workflows/Build%20MSIXBuilder%20GUI/badge.svg)](https://github.com/MHaggis/MSIXBuilder/actions)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## 🎯 What is MSIXBuilder?

MSIXBuilder is a comprehensive PowerShell tool that creates functional MSIX packages with embedded test applications. It's designed specifically for:

- **🔴 Red Team Operations** - Create realistic attack scenarios using MSIX containers
- **🔵 Blue Team Validation** - Test detection rules and monitoring systems
- **🟢 Security Research** - Analyze MSIX container behavior and isolation
- **🟡 Detection Engineering** - Generate IOCs, YARA rules, and telemetry data

## ✨ Key Features

### 🚀 **Automated Everything**
- **Zero-config dependency management** - Automatically downloads and installs .NET Framework Developer Pack, Windows SDK
- **Smart certificate generation** - Creates and manages code signing certificates
- **One-click package creation** - From source code to signed MSIX in minutes

### 🎛️ **Flexible Payload Options**
- **C# Applications** - Compiled .NET executables with advanced capabilities
- **PowerShell Scripts** - With C# wrapper for MSIX compatibility
- **Hybrid Approach** - Best of both worlds for comprehensive testing

### 🔍 **Detection & Telemetry Integration**
- **Real-time monitoring** guidance for blue teams
- **YARA rule generation** for threat hunting
- **JSON log exports** with IOCs and detection points
- **Event log analysis** with specific Event IDs to monitor

### 🎨 **Modern GUI Interface**
- **Windows Forms** interface with modern design
- **Real-time progress tracking** with visual feedback
- **Template management** for common scenarios
- **One-click certificate installation** for easy deployment
- **Comprehensive logging** with built-in log viewer
- **Built and distributed via GitHub Actions**

## 🛠️ Installation & Usage

### **Prerequisites**
- **Windows 10 (1809+) or Windows 11**
- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Administrator privileges** (required for package creation and certificate installation)
- **.NET 8.0 Runtime** (for GUI application)

### **Auto-Installed Dependencies**
MSIXBuilder automatically downloads and installs:
- **.NET Framework 4.8.1 Developer Pack**
- **Windows SDK 10.0.17763+** (MakeAppx, SignTool)
- **Visual C++ Redistributables** (if needed)

### **Method 1: GUI Application (Recommended)**
1. Download the latest release from [GitHub Releases](https://github.com/MHaggis/MSIXBuilder/releases)
2. Extract and run `MSIXBuilderGUI.exe`
3. Configure your package settings using the intuitive interface
4. Click "Create Package" and let the automation handle the rest!
5. Use the "Install Certificate" button for easy deployment

### **Method 2: PowerShell Script**
```powershell
# Download and run directly
git clone https://github.com/MHaggis/MSIXBuilder.git
cd MSIXBuilder
.\Create-MSIXPackage.ps1
```

## 🎯 Usage Examples

### **Basic Security Testing**
```powershell
.\Create-MSIXPackage.ps1 -PackageName "RedTeamTest" -Publisher "SecurityResearch" -AppType "Both"
```

### **Advanced Telemetry Mode**
```powershell
.\Create-MSIXPackage.ps1 -TelemetryMode -GenerateDetectionLogs
```

### **Advanced Payload Testing**
```powershell
.\Create-MSIXPackage.ps1 -TelemetryMode
```

## 📋 Parameters Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `PackageName` | String | Name of the MSIX package | Interactive prompt |
| `Publisher` | String | Publisher name for certificate | Interactive prompt |
| `OutputPath` | String | Directory to create package in | Interactive prompt |
| `AppType` | String | 'CSharp', 'PowerShell', or 'Both' | Interactive prompt |
| `TelemetryMode` | Switch | Enable comprehensive logging | False |
| `GenerateDetectionLogs` | Switch | Create JSON logs and YARA rules | False |
| `SkipDownloads` | Switch | Skip automatic dependency downloads | False |

## 🔍 Detection Points & Monitoring

MSIXBuilder creates packages that trigger multiple detection points:

### **📊 Event Logs to Monitor**
- **AppxDeployment-Server**: `Microsoft-Windows-AppxDeployment-Server/Operational`
- **AppXPackaging**: `AppXPackaging/Operational`
- **PowerShell ScriptBlock**: Event ID `4104`
- **Process Creation**: Event ID `4688` (if enabled)
- **Certificate Installation**: Event ID `4768`, `4769`

### **🕵️ Behavioral Indicators**
- MSIX package installation via `Add-AppPackage`
- PowerShell execution from WindowsApps directory
- WMI queries for domain membership (`Win32_ComputerSystem`)
- File creation in `%LOCALAPPDATA%\{PackageName}Test`
- Certificate installation to TrustedPeople store

### **📝 Generated Artifacts**
- **DetectionLog.json** - Comprehensive IOC and detection data
- **DetectionRule.yar** - YARA rule for threat hunting
- **Package file hashes** (SHA256) for allowlisting/blocklisting

## 🎨 GUI Features

The MSIXBuilder GUI provides:

- **📋 Configuration Panel** - Easy form-based input for all package settings
- **📊 Real-time Progress** - Visual progress tracking with detailed status updates
- **🔧 One-Click Operations** - Create packages and install certificates with single clicks
- **📝 Comprehensive Logging** - Built-in log viewer for troubleshooting and monitoring
- **🛡️ Security Integration** - Automatic privilege elevation and certificate management
- **⚡ Non-Interactive Execution** - Streamlined PowerShell execution without user prompts

## 🤝 Contributing

We welcome contributions! Open up a PR!

## 📞 Support & Contact

- **GitHub Issues**: [Report bugs or request features](https://github.com/MHaggis/MSIXBuilder/issues)

---

<div align="center">

**Made with ❤️ for the cybersecurity community**

[⭐ Star this repo](https://github.com/MHaggis/MSIXBuilder) • [🐛 Report issues](https://github.com/MHaggis/MSIXBuilder/issues) 

</div> 