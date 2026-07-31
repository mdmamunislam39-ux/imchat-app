# 1. Install Node.js quietly
Write-Host "Installing Node.js..." -ForegroundColor Cyan
winget install -e --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements

# 2. Refresh the terminal's memory to recognize 'npm'
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$env:Path += ";C:\Program Files\nodejs\"

# 3. Install Firebase globally
Write-Host "Installing Firebase..." -ForegroundColor Cyan
npm install -g firebase-tools

# 4. Refresh PATH again for 'firebase'
$env:Path += ";$env:APPDATA\npm"

# 5. Log in to Firebase
Write-Host "Logging into Firebase..." -ForegroundColor Cyan
firebase login

# 6. Deploy the custom domain deep link file!
Write-Host "Deploying to Firebase Hosting..." -ForegroundColor Green
firebase deploy --only hosting

Write-Host "ALL DONE! Please wait 5 minutes and then test your link on your phone!" -ForegroundColor Green
