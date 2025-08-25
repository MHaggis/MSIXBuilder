# Assets Folder

This folder should contain the following image files for the WinUI3 application:

## Required Images

All images should be PNG format with transparency support:

- **StoreLogo.png** (50x50) - Store logo
- **Square44x44Logo.png** (44x44) - Small tile logo
- **Square44x44Logo.targetsize-24_altform-unplated.png** (24x24) - Unplated icon
- **Square150x150Logo.png** (150x150) - Medium tile logo  
- **Wide310x150Logo.png** (310x150) - Wide tile logo
- **LockScreenLogo.png** (24x24) - Lock screen badge logo
- **SplashScreen.png** (620x300) - Splash screen image
- **icon.ico** - Application icon file

## Creating Assets

You can create simple placeholder images using PowerShell:

```powershell
# Create a simple 1x1 transparent PNG as base64
$pngBytes = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")

# Create all required image files
$imageFiles = @(
    "StoreLogo.png",
    "Square150x150Logo.png",
    "Square44x44Logo.png", 
    "Square44x44Logo.targetsize-24_altform-unplated.png",
    "Wide310x150Logo.png",
    "LockScreenLogo.png",
    "SplashScreen.png"
)

foreach ($imageFile in $imageFiles) {
    [System.IO.File]::WriteAllBytes($imageFile, $pngBytes)
}
```

For production use, replace these with proper branded images. 