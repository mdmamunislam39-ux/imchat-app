Write-Host "Installing Java JDK 17 automatically..." -ForegroundColor Cyan
winget install -e --id Microsoft.OpenJDK.17 --silent --accept-package-agreements --accept-source-agreements

$javaPath = Get-ChildItem "C:\Program Files\Microsoft\jdk-17*" | Select-Object -First 1
if ($javaPath) {
    # Set it permanently for the User
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaPath.FullName, "User")
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notmatch "JAVA_HOME") {
        [System.Environment]::SetEnvironmentVariable("Path", $currentPath + ";%JAVA_HOME%\bin", "User")
    }
    
    # Set it for this terminal session right now
    $env:JAVA_HOME = $javaPath.FullName
    $env:Path = "$env:JAVA_HOME\bin;" + $env:Path
    Write-Host "Successfully installed and configured JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Green
} else {
    Write-Host "Java installation failed. Please install it manually." -ForegroundColor Red
    exit 1
}

# 2. Generate Release Keystore automatically
$keystorePath = "android/upload-keystore.jks"
if (-Not (Test-Path $keystorePath)) {
    Write-Host "Generating Release Keystore..." -ForegroundColor Cyan
    & keytool -genkey -v -keystore $keystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias upload -dname "CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown" -storepass android -keypass android
    Write-Host "Keystore Generated Successfully!" -ForegroundColor Green
}

# 3. Clean and Build
Write-Host "Cleaning project and fetching dependencies..." -ForegroundColor Cyan
flutter clean
flutter pub get

Write-Host "Building Release APK..." -ForegroundColor Cyan
flutter build apk --release

Write-Host "DONE! Your APK should be at build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Green
