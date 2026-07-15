$ErrorActionPreference = "Stop"

# Load variables from .env (same role as `source .env` in build.sh)
Get-Content -Path (Join-Path $PSScriptRoot ".env") | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) {
        return
    }
    $parts = $line.Split("=", 2)
    if ($parts.Count -ne 2) {
        return
    }
    $name = $parts[0].Trim()
    $value = $parts[1].Trim().Trim("'").Trim('"')
    Set-Item -Path "Env:$name" -Value $value
}

$env:DOCKER_BUILDKIT = "1"

# Equivalent of: echo -n "$(date +'%Y.%m.%d-%H%M')" | md5sum | awk '{print $1}'
$dateStr = Get-Date -Format "yyyy.MM.dd-HHmm"
$md5 = [System.Security.Cryptography.MD5]::Create()
try {
    $hashBytes = $md5.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($dateStr))
    $dsVersionHash = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
}
finally {
    $md5.Dispose()
}

$composeArgs = @(
    "-f", "build.yml", "build",
    "--build-arg", "DOCKERFILE=$($env:DOCKERFILE)",
    "--build-arg", "PRODUCT_EDITION=$($env:PRODUCT_EDITION)",
    "--build-arg", "RELEASE_VERSION=$($env:RELEASE_VERSION)",
    "--build-arg", "DS_VERSION_HASH=$dsVersionHash"
)

Push-Location $PSScriptRoot
try {
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        & docker-compose @composeArgs
    }
    else {
        & docker compose @composeArgs
    }
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
