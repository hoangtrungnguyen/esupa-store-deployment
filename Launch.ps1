# --- Configuration ---
$composeDir = "docker"
$flutterDir = "frontend\windows\runner\Release"
$flutterExe = "your_flutter_app.exe" # <-- Change this
$backendServiceName = "backend" # <-- Must match the service name in docker-compose.yml
$waitTimeoutSeconds = 90 # How long to wait for the backend to become healthy (adjust as needed)
# --- End Configuration ---

# Get the directory where the script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- Check if Docker Desktop is running ---
Write-Host "Checking if Docker Desktop is running..."
try {
    # Attempt a simple docker command to see if it responds
    docker ps -q | Out-Null
    if ($LASTEXITCODE -ne 0) {
         throw "Docker command failed." # This catches cases where docker command exists but daemon is off
    }
} catch {
    Write-Error "Error: Docker Desktop is not running or not installed."
    Write-Error "Please start Docker Desktop and try again."
    Read-Host "Press Enter to exit..."
    Exit 1
}
Write-Host "Docker Desktop is running."
# --- End Docker Check ---

# --- Start Docker Services ---
Write-Host "Starting backend, database, and Watchtower services via Docker Compose..."
$composePath = Join-Path $scriptDir $composeDir
Push-Location $composePath # Change to the directory containing docker-compose.yml
try {
    # -d runs containers in detached mode (in the background)
    # --build ensures images are built initially if needed (Watchtower handles subsequent updates from registry)
    docker-compose up -d --build
    if ($LASTEXITCODE -ne 0) {
        throw "docker-compose up failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Error "Error: Failed to start Docker services."
    $_.Exception | Format-List * # Show error details
    Pop-Location # Change back to original directory
    Read-Host "Press Enter to exit..."
    Exit 1
}
Pop-Location # Change back to original directory
Write-Host "Docker services started in the background."

# --- Wait for Backend to be Healthy ---
Write-Host "Waiting for backend service ($backendServiceName) to become healthy (timeout in $waitTimeoutSeconds seconds)..."
$startTime = Get-Date
$endTime = $startTime.AddSeconds($waitTimeoutSeconds)
$isHealthy = $false

while ((Get-Date) -lt $endTime) {
    try {
        # Get container ID for the backend service
        $containerId = docker-compose -f (Join-Path $scriptDir $composeDir "docker-compose.yml") ps -q $backendServiceName

        if (-not $containerId) {
            Write-Host "Backend container not found yet, waiting..."
            Start-Sleep -Seconds 3 # Wait a bit longer if container isn't even listed
            continue
        }

        # Get health status of the container
        $status = docker inspect --format '{{json .State.Health}}' $containerId | ConvertFrom-Json | Select-Object -ExpandProperty Status

        if ($status -eq "healthy") {
            $isHealthy = $true
            break
        } elseif ($status -eq "unhealthy") {
             Write-Error "Backend service reported as unhealthy. Check container logs."
             break
        }
        # Status is "starting" or null initially
        Write-Host "Backend status: $status. Waiting..."
    } catch {
        # Handle potential errors if container inspection fails temporarily
        Write-Host "Could not get backend status, waiting... ($($_.Exception.Message))"
    }
    Start-Sleep -Seconds 5 # Wait 5 seconds before checking again
}

if (-not $isHealthy) {
    Write-Error "Timeout waiting for backend service ($backendServiceName) to become healthy."
    Write-Host "Check Docker logs for the backend container for details:"
    Write-Host "  docker-compose -f ""$(Join-Path $scriptDir $composeDir "docker-compose.yml")"" logs $backendServiceName"
    Read-Host "Press Enter to exit..."
    Exit 1
}
Write-Host "Backend service is healthy."
# --- End Wait for Backend ---

# --- Launch Flutter Frontend ---
Write-Host "Launching Flutter frontend..."
$flutterExePath = Join-Path $scriptDir $flutterDir $flutterExe
if (Test-Path $flutterExePath) {
    Start-Process -FilePath $flutterExePath
    Write-Host "Flutter frontend launched."
} else {
    Write-Error "Error: Flutter executable not found at '$flutterExePath'"
    Read-Host "Press Enter to exit..."
    Exit 1
}

Write-Host ""
Write-Host "Application stack is running. The Flutter app should now be visible."
Write-Host "To stop the backend and database services (but NOT the Flutter app), run the Stop.ps1 script."

# Keep the PowerShell window open until services are stopped or script is closed
# This allows users to see output or errors if not running detached.
# If you want the window to close immediately, remove the Read-Host or adjust logic.
# Read-Host "Press Enter to close this window (Docker services will keep running)..."

Exit 0
