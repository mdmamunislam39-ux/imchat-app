# 1. Setup Firebase CLI
Write-Host "Downloading Standalone Firebase CLI..." -ForegroundColor Cyan
Invoke-WebRequest -Uri "https://firebase.tools/bin/win/instant/firebase-tools-windows.exe" -OutFile "firebase.exe"

# 2. Extract SHA256 Key Automatically
Write-Host "Extracting SHA256 Fingerprint from Android Studio..." -ForegroundColor Cyan
$keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if (-Not (Test-Path $keytoolPath)) {
    $keytoolPath = "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe"
}

if (Test-Path $keytoolPath) {
    # Run keytool and extract the SHA256 line
    $keytoolOutput = & $keytoolPath -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
    $sha256Line = $keytoolOutput | Select-String "SHA256: "
    
    if ($sha256Line) {
        $sha256Key = ($sha256Line -split "SHA256: ")[1].Trim()
        Write-Host "✅ Found SHA256 Key: $sha256Key" -ForegroundColor Green

        # 3. Write to assetlinks.json
        $assetlinksPath = "public\.well-known\assetlinks.json"
        $jsonContent = @"
[
  {
    "relation": [
      "delegate_permission/common.handle_all_urls"
    ],
    "target": {
      "namespace": "android_app",
      "package_name": "com.imchat",
      "sha256_cert_fingerprints": [
        "$sha256Key"
      ]
    }
  }
]
"@
        Set-Content -Path $assetlinksPath -Value $jsonContent
        Write-Host "✅ assetlinks.json successfully updated!" -ForegroundColor Green
    } else {
        Write-Host "❌ Could not extract SHA256 key." -ForegroundColor Red
    }
} else {
    Write-Host "❌ Could not find keytool.exe in Android Studio folder." -ForegroundColor Red
}

# 4. Login and Deploy
Write-Host "Logging into Firebase..." -ForegroundColor Cyan
.\firebase.exe login

Write-Host "Deploying Hosting Configuration..." -ForegroundColor Cyan
.\firebase.exe deploy --only hosting

Write-Host "🎉 DEPLOYMENT COMPLETE! App Links should now be working." -ForegroundColor Green
