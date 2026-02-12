# ===== STOP LOCAL STACK (Windows) =====
# Stops services by killing whatever is LISTENING on ports:
# - 8000 (AI backend)
# - 8001 (RAG backend)
# - 11434 (Ollama) [optional]

param(
  [switch]$StopOllama
)

$ErrorActionPreference = "SilentlyContinue"

function Kill-Port($port) {
  Write-Host "Checking port $port..."
  $lines = netstat -ano | findstr ":$port" | findstr "LISTENING"
  if (-not $lines) {
    Write-Host "  No LISTENING process found on port $port."
    return
  }

  $pids = @()
  foreach ($line in $lines) {
    $parts = ($line -split "\s+") | Where-Object { $_ -ne "" }
    # PID is the last column
    $pid = $parts[-1]
    if ($pid -match "^\d+$") { $pids += $pid }
  }

  $pids = $pids | Sort-Object -Unique
  foreach ($pid in $pids) {
    Write-Host "  Killing PID $pid on port $port..."
    taskkill /PID $pid /F | Out-Null
  }
}

# Always stop backend + rag
Kill-Port 8000
Kill-Port 8001

if ($StopOllama) {
  Kill-Port 11434
} else {
  Write-Host "Skipping Ollama (11434). Use: .\stop_local.ps1 -StopOllama"
}

Write-Host "Done."
