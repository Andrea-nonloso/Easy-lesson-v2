# Prepara il progetto Easy Lesson 2 (da eseguire una sola volta, in PowerShell,
# dentro questa cartella). Serve Flutter installato e nel PATH.
# Per la versione Windows serve anche Visual Studio 2022 con il carico di lavoro
# "Sviluppo di applicazioni desktop con C++".
#
# Se PowerShell blocca lo script:
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Write-Utf8($path, $text) {
  [IO.File]::WriteAllText((Resolve-Path $path), $text, (New-Object Text.UTF8Encoding $false))
}

# 1. Abilita Windows desktop e genera le cartelle mancanti (i file gia' presenti non vengono toccati)
flutter config --enable-windows-desktop
flutter create . --project-name easy_lesson --org it.easylesson --platforms=android,ios,web,windows

# 2. Finestra Windows: titolo "Easy Lesson" e dimensione iniziale
$main = "windows\runner\main.cpp"
if (Test-Path $main) {
  $t = [IO.File]::ReadAllText((Resolve-Path $main))
  $t = $t -replace 'L"easy_lesson"', 'L"Easy Lesson"'
  $t = $t -replace 'Size size\(1280, 720\)', 'Size size(1100, 780)'
  Write-Utf8 $main $t
}
$rc = "windows\runner\Runner.rc"
if (Test-Path $rc) {
  $t = [IO.File]::ReadAllText((Resolve-Path $rc))
  $t = $t -replace '"easy_lesson" "\\0"', '"Easy Lesson" "\0"'
  $t = $t -replace '"it\.easylesson" "\\0"', '"Easy Lesson" "\0"'
  Write-Utf8 $rc $t
}

# 3. Dipendenze
flutter pub get

# 4. Icone dell'app (Android, iOS, web, Windows)
dart run flutter_launcher_icons

# 5. Controlli
flutter analyze
flutter test

Write-Host ""
Write-Host "Fatto! Prova l'app con:"
Write-Host "  flutter run -d windows     (app Windows)"
Write-Host "  flutter run -d chrome      (web)"
Write-Host "  flutter run                (telefono collegato)"
Write-Host ""
Write-Host "Per creare la versione Windows da distribuire:  .\build_windows.ps1"
