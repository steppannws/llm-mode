# client-connect.ps1 — Windows client; tunnels the LLM API from the server.
# Needs the built-in OpenSSH client (Windows 10 1809+ / Windows 11).
# usage: .\client-connect.ps1 [you@server.local] [port] [-DryRun]
param(
  [string]$Target = $(if ($env:LLM_HOST) { $env:LLM_HOST } else { "stepan@m4.local" }),
  [int]$Port = $(if ($env:LLM_PORT) { [int]$env:LLM_PORT } else { 1234 }),
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"

$SshArgs = @("-N", "-L", "${Port}:localhost:${Port}", $Target)
$Api = "http://localhost:$Port/v1"
Write-Output "tunnel: ssh $($SshArgs -join ' ')"
Write-Output "API when up: $Api  (OpenAI-compatible)"
Write-Output "aider: aider --openai-api-base $Api --openai-api-key local"
if ($DryRun) { exit 0 }

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
  throw "ssh not found. Install it: Settings > Apps > Optional features > OpenSSH Client"
}

$Tunnel = Start-Process ssh -ArgumentList $SshArgs -NoNewWindow -PassThru
try {
  Write-Output "waiting for API..."
  for ($i = 0; $i -lt 30; $i++) {
    if ($Tunnel.HasExited) { throw "ssh exited (code $($Tunnel.ExitCode))" }
    try {
      Invoke-WebRequest -Uri "$Api/models" -UseBasicParsing -TimeoutSec 2 | Out-Null
      Write-Output "API ready."
      break
    } catch { Start-Sleep -Seconds 2 }
  }
  $Tunnel.WaitForExit()
} finally {
  if (-not $Tunnel.HasExited) { Stop-Process -Id $Tunnel.Id -Force }
}
