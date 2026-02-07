function Show-EnvHelp {
  param(
    [string]$envPath,
    [string]$templatePath
  )

  Write-Host ""
  Write-Host "Missing .env file."
  Write-Host "Create it with:"
  Write-Host "  cp .env.template .env"
  Write-Host ""
  Write-Host "Fill in at least:"
  Write-Host "  DOMAIN=your.domain.tld"
  Write-Host "  LE_EMAIL=you@domain.tld"
  Write-Host "  CF_DNS_API_TOKEN=your-cloudflare-api-token"
  Write-Host "  CREATE_ADMIN=True|False"
  Write-Host ""
  Write-Host "Then re-run this installer."
  Write-Host ""
}

function Read-EnvFile {
  param(
    [string]$envPath
  )

  $vars = @{}
  Get-Content $envPath | ForEach-Object {
    $line = $_.Trim()
    if (-not $line) { return }
    if ($line.StartsWith("#")) { return }
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') {
      $key = $Matches[1]
      $value = $Matches[2].Trim()
      if ($value.StartsWith('"') -and $value.EndsWith('"')) {
        $value = $value.Substring(1, $value.Length - 2)
      } elseif ($value.StartsWith("'") -and $value.EndsWith("'")) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      $vars[$key] = $value
    }
  }
  return $vars
}

function Validate-Env {
  param(
    [hashtable]$envVars,
    [string]$envPath,
    [string]$templatePath
  )

  $domain = $envVars["DOMAIN"]
  $leEmail = $envVars["LE_EMAIL"]
  $cfToken = $envVars["CF_DNS_API_TOKEN"]
  $createAdminRaw = $envVars["CREATE_ADMIN"]

  if (-not $domain -or $domain -eq "domain.tld") {
    Write-Host "DOMAIN is missing or still set to the example value."
    Show-EnvHelp -envPath $envPath -templatePath $templatePath
    exit 1
  }

  if (-not $leEmail -or $leEmail -eq "email@domain.tld") {
    Write-Host "LE_EMAIL is missing or still set to the example value."
    Show-EnvHelp -envPath $envPath -templatePath $templatePath
    exit 1
  }

  if (-not $cfToken -or $cfToken -eq "secret") {
    Write-Host "CF_DNS_API_TOKEN is missing or still set to the example value."
    Show-EnvHelp -envPath $envPath -templatePath $templatePath
    exit 1
  }

  if (-not $createAdminRaw) {
    Write-Host "CREATE_ADMIN is missing."
    Show-EnvHelp -envPath $envPath -templatePath $templatePath
    exit 1
  }

  $createAdminNormalized = $createAdminRaw.ToLower()
  if ($createAdminNormalized -ne "true" -and $createAdminNormalized -ne "false") {
    Write-Host "CREATE_ADMIN must be True or False."
    Show-EnvHelp -envPath $envPath -templatePath $templatePath
    exit 1
  }
}
