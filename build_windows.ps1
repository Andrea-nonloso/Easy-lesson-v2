# Crea la versione Windows di Easy Lesson da distribuire.
# Risultato in .\dist :
#   - EasyLesson-Windows.zip          (versione portatile: estrai e avvia easy_lesson.exe)
#   - EasyLesson-Setup-2.0.0.exe      (installer, solo se e' installato Inno Setup 6)
#
# Prima volta: eseguire .\setup.ps1
param(
  [string]$Version,        # es. 2.0.1 (default: quella in pubspec.yaml)
  [int]$BuildNumber = 1,
  [string]$Tag = ""        # es. v2.5.0-beta.1: passato alla CI via --dart-define=EL_TAG
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not $Version) {
  $Version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
}
Write-Host "Versione $Version"
if ($Tag) {
  flutter build windows --release --build-name=$Version --build-number=$BuildNumber "--dart-define=EL_TAG=$Tag"
} else {
  flutter build windows --release --build-name=$Version --build-number=$BuildNumber
}
if ($LASTEXITCODE -ne 0) { throw "flutter build windows non riuscito" }

$rel = "build\windows\x64\runner\Release"
if (-not (Test-Path "$rel\easy_lesson.exe")) { throw "Build non trovata in $rel" }

# Librerie Visual C++ necessarie sui PC che non le hanno gia'
foreach ($dll in "msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll") {
  $src = Join-Path $env:WINDIR "System32\$dll"
  if (Test-Path $src) { Copy-Item $src $rel -Force }
}

New-Item -ItemType Directory -Force dist | Out-Null
$zip = "dist\EasyLesson-Windows.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$rel\*" -DestinationPath $zip
Write-Host "Versione portatile: $zip"

$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if ($iscc) {
  & $iscc "/DMyAppVersion=$Version" "installer\easy_lesson.iss"
  Write-Host "Installer creato in dist\"
} else {
  Write-Host "Inno Setup 6 non trovato: installer saltato (scaricalo da jrsoftware.org se ti serve)."
}

