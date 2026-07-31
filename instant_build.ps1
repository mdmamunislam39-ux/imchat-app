Write-Host "Downloading Portable Java JDK 17..." -ForegroundColor Cyan
curl.exe -L "https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_windows-x64_bin.zip" -o java.zip

Write-Host "Extracting Java (This may take a minute)..." -ForegroundColor Cyan
Expand-Archive -Path java.zip -DestinationPath . -Force
Remove-Item java.zip

Write-Host "Configuring JAVA_HOME for this terminal..." -ForegroundColor Cyan
$env:JAVA_HOME = "$PWD\jdk-17.0.2"
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

Write-Host "Increasing Dart Memory Limit..." -ForegroundColor Cyan
$env:DART_VM_OPTIONS="--old_gen_heap_size=8192"

Write-Host "Cleaning Project..." -ForegroundColor Cyan
flutter clean
flutter pub get

Write-Host "Building Release APK..." -ForegroundColor Green
flutter build apk --release
