#!pwsh
# Stop.ps1
# Script to stop the Docker services launched by docker-compose

# --- Configuration ---
$composeDir = "docker"
# --- End Configuration ---

# Get the directory where the script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- Check if Docker is running ---
Write-Host "Checking if Docker Desktop is running..."
try {
    docker ps -q | Out-Null
    if ($LASTEXITCODE -ne 0) {
         throw "Docker command failed."
    }
} catch {
    Write-Host "Docker Desktop is not running or not installed. Services might not have been started or already stopped."
    Read-Host "Press Enter to exit..."
    Exit 1
}
Write-Host "Docker is running."
# --- End Docker Check ---

# --- Stop Docker Services ---
Write-Host "Stopping Docker services via Docker Compose..."
$composePath = Join-Path $scriptDir $composeDir
Push-Location $composePath # Change to the directory containing docker-compose.yml
try {
    # 'down' stops and removes containers and networks defined in the compose file
    # Use --volumes if you also want to delete the database data (CAUTION!)
    # docker-compose down --volumes
    docker-compose down
    if ($LASTEXITCODE -ne 0) {
         throw "docker-compose down failed with exit code $LASTEXITCODE"
    }
} catch {
     Write-Error "Error: Failed to stop Docker services."
     $_.Exception | Format-List * # Show error details
     Pop-Location # Change back to original directory
     Read-Host "Press Enter to exit..."
     Exit 1
}
Pop-Location # Change back to original directory
Write-Host "Docker services stopped."

# Note: This script does NOT stop the Flutter app. Close it manually if it's still running.

Exit 0