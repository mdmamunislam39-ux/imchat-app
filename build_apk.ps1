$androidStudioPath = "C:\Program Files\Android\Android Studio"
$jbrPath = Join-Path $androidStudioPath "jbr"
$jrePath = Join-Path $androidStudioPath "jre"

if (Test-Path $jbrPath) {
    $env:JAVA_HOME = $jbrPath
} elseif (Test-Path $jrePath) {
    $env:JAVA_HOME = $jrePath
} else {
    Write-Host "Could not find Android Studio's bundled Java. Attempting to search common JDK paths..." -ForegroundColor Yellow
    # Fallback to Program Files\Java
    $javaPath = Get-ChildItem "C:\Program Files\Java" -Filter "jdk*" | Select-Object -First 1
    if ($javaPath) {
        $env:JAVA_HOME = $javaPath.FullName
    } else {
        Write-Host "No Java installed. Please install Java JDK 17 from Oracle or Adoptium." -ForegroundColor Red
        exit 1
    }
}

$env:Path = "$env:JAVA_HOME\bin;" + $env:Path
Write-Host "Successfully configured JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Green

Write-Host "Starting Flutter Release Build..." -ForegroundColor Cyan
flutter build apk --release
