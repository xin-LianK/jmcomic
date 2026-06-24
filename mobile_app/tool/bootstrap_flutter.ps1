if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter SDK is not on PATH. Install Flutter first, then rerun this script."
  exit 1
}

flutter create --platforms=android,ios,web .
flutter pub get
