# --- Configuration ---
# Define the path to your project directory
$PROJECT_DIR = "C:\Users\nguye\StudioProjects\ebond-pos-flutter-windows-app" # <--- !!! CHANGE THIS TO YOUR PROJECT PATH !!!

# Define the directory where the appcast XML files are stored
$APPCAST_DIR = "C:\Users\nguye\OneDrive\Desktop\config\build_app" # <--- !!! CHANGE THIS TO THE DIRECTORY CONTAINING YOUR XML FILES !!!

# Define the path to the distribute_options.yaml file
$DISTRIBUTE_OPTIONS_FILE = Join-Path $PROJECT_DIR "distribute_options.yaml"

# --- Functions ---

# Function to check if a command exists
function command_exists {
  param(
    [string]$command
  )
  Get-Command $command -ErrorAction SilentlyContinue | Out-Null
  return $LASTEXITCODE -eq 0 # Check if Get-Command found anything
}

# Function to install Flutter Distributor
function install_flutter_distributor {
  Write-Host "Flutter Distributor not found. Installing..."
  dart pub global activate flutter_distributor
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Flutter Distributor installed successfully."
  } else {
    Write-Host "Error installing Flutter Distributor. Please install it manually by running 'dart pub global activate flutter_distributor'."
    exit 1
  }
}

# Function to install auto_updater
function install_auto_updater {
  Write-Host "auto_updater not found. Please install it as a Flutter package in your project."
  Write-Host "You can add it to your pubspec.yaml file and run 'flutter pub get'."
  exit 1
}

# Function to install OpenSSL
function install_openssl {
  Write-Host "OpenSSL not found. Installing with Chocolatey..."
  Write-Host "You may need administrator privileges to run this command."
  Start-Process powershell -ArgumentList "-Command `"Start-Process choco install openssl -Verb runAs`"" -Verb RunAs -Wait -NoNewWindow
  Write-Host "Please wait for the OpenSSL installation to complete and then re-run the script."
  exit 1
}

# Function to install Inno Setup 6
function install_inno_setup {
  Write-Host "Inno Setup 6 not found. Please download and install it from: https://jrsoftware.org/isdl.php"
  exit 1
}


# Step 2: Select build type
Write-Host "Select the build type:"
Write-Host "1) test"
Write-Host "1.1) test api sorting"
Write-Host "2) staging (uat nội bộ)"
Write-Host "3) uat (uat khách hàng)"
Write-Host "4) prod (product)"
$build_choice = Read-Host -Prompt "Enter the number of the build type"

$build_name = ""
$appcast_file = ""

switch ($build_choice) {
  "1" {
    $build_name = "test"
    $appcast_file = Join-Path $APPCAST_DIR "appcast.xml"
  }
  "1.1" {
    $build_name = "test_api"
    $appcast_file = Join-Path  $APPCAST_DIR "appcast_test_api_pos_setup.xml"
  }
  "2" {
    $build_name = "staging"
    $appcast_file = Join-Path $APPCAST_DIR "appcast_staging.xml"
  }
  "3" {
    $build_name = "uat"
    $appcast_file = Join-Path $APPCAST_DIR "appcast_uat.xml"
  }
  "4" {
    $build_name = "prod"
    $appcast_file = Join-Path $APPCAST_DIR "appcast_prod.xml"
  }
  default {
    Write-Host "Invalid choice. Exiting."
    exit 1
  }
}

Write-Host "Selected build type: $build_name"

# Step 6: Rename the generated .exe file based on build type
# Get version from pubspec.yaml first to find the correct dist folder
$pubspec_file = Join-Path $PROJECT_DIR "pubspec.yaml"
Write-Host "pubspec.yaml "
if (-not (Test-Path $pubspec_file)) {
  Write-Host "Error: pubspec.yaml not found in $PROJECT_DIR. Cannot get version. Exiting."
  exit 1
}

$app_version = ""
# Read the entire pubspec.yaml file as a single string
$pubspec_content = Get-Content $pubspec_file -Raw

Write-Host "pubspec_content: $pubspec_content "
# Use regex to find and extract the version from the single string content
if ($pubspec_content -match "(?m)^\s*version: (\S+)") {
  # Print the entire $Matches hashtable
    Write-Host "DEBUG: \$Matches content:"
    Write-Host $Matches

    # Print specific elements of $Matches
    Write-Host "DEBUG: \$Matches[0] (Whole match): $($Matches[0])"
    Write-Host "DEBUG: \$Matches[1] (First capturing group): $($Matches[1])"

    $app_version = $Matches[1] # $Matches[1] holds the content of the first capturing group (\S+)
}

if ([string]::IsNullOrEmpty($app_version)) {
  Write-Host "Error: Could not extract version from pubspec.yaml. Exiting."
  break
}

Write-Host "App version from pubspec.yaml: $app_version"

# Construct the expected directory for the generated exe file (e.g., dist/1.0.0+1)
$expected_generated_dir = Join-Path (Join-Path $PROJECT_DIR "dist") $app_version

# Find the generated exe file directly in the expected versioned directory
Write-Host "Looking for generated exe in: $expected_generated_dir"
$generated_exe = Get-ChildItem -Path $expected_generated_dir -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName


if (-not $generated_exe) {
  # If not found in the expected version folder, try a recursive search as a fallback
  Write-Host "Warning: .exe not found in expected version directory '$expected_generated_dir'. Attempting recursive search in dist/..."
  $generated_exe = Get-ChildItem -Path (Join-Path $PROJECT_DIR "dist") -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

  if (-not $generated_exe) {
      Write-Host "Error: Could not find the generated .exe file in $PROJECT_DIR\dist or any subdirectory. Exiting."

  } else {
      Write-Host "Found .exe via recursive search: $generated_exe"
  }
}

Write-Host "Generated exe file: $generated_exe"


# Determine the expected exe name based on the build_name
$expected_exe_name = ""
switch ($build_name) {
  "test" {
    $expected_exe_name = "test_pos_setup.exe"
  }
  "test_api" {
    $expected_exe_name = "test_api_pos_setup.exe"
  }
  "staging" {
    $expected_exe_name = "staging_pos_setup.exe"
  }
  "uat" {
    $expected_exe_name = "uat_pos_setup.exe"
  }
  "prod" {
    $expected_exe_name = "prod_pos_setup.exe"
  }
  default {
    Write-Host "Error: Unknown build name '$build_name'. Cannot determine expected exe name. Exiting."
  }
}

if ([string]::IsNullOrEmpty($expected_exe_name)) {
  Write-Host "Error: Could not determine the expected exe name for build type '$build_name'. Exiting."

} else {
  $generated_dir = Split-Path -Parent $generated_exe
  $renamed_exe = Join-Path $generated_dir $expected_exe_name
  Write-Host "Renaming $generated_exe to $renamed_exe"
  Move-Item $generated_exe $renamed_exe -Force # Use -Force to overwrite if necessary
  Write-Host "Exe file ready for signing: $renamed_exe"
}


# Step 7: Sign the update
Write-Host "Running dart run auto_updater:sign_update..."

# Ensure we are in the project directory before running the signing command
Set-Location $PROJECT_DIR -ErrorAction Stop

# Check if auto_updater package is available by trying to run its help command
if (-not (dart run auto_updater:sign_update --help 2>&1 | Out-String)) {
  install_auto_updater
}

# Check for openssl
# if (-not (command_exists "openssl")) { install_openssl }

# Check for Inno Setup 6 (This check might not be perfect, relies on the error message)
# A more robust check would involve looking in Program Files, but this is a quick check.
# We'll run the signing command and check the output for the specific error message.
$signing_output = dart run auto_updater:sign_update $renamed_exe 2>&1 | Out-String

Write-Host "Signing data $signing_output"
Write-Host "Signing completed."
Write-Host "Signing output:"
Write-Host $signing_output

# Extract the hash from the signing output
# Assuming the hash is on a line like: "Generated signature: YOUR_HASH_HERE"
$generated_hash = ""
if ($signing_output -match 'sparkle:dsaSignature="(?<hash>.*?)"') {
    $generated_hash = $Matches.hash # Access the named capture group
}
# Fallback regex in case the output format is different (like the original expectation)
if ([string]::IsNullOrEmpty($generated_hash) -and ($signing_output -match "Generated signature: (\S+)")) {
     $generated_hash = $Matches[1]
}


if ([string]::IsNullOrEmpty($generated_hash)) {
  Write-Host "Warning: Could not extract the generated hash from the signing output."
} else {
  Write-Host "Generated hash: $generated_hash"
  # Step 8: Update sparkle:dsaSignature attribute in appcast.xml
  Write-Host "Updating $appcast_file with the generated hash..."

  # Load the XML file
  [xml]$appcast_xml = Get-Content $appcast_file

  # Find the enclosure node (assuming there's only one item and one enclosure per item)
  $enclosure_node = $appcast_xml.rss.channel.item.enclosure

  if ($enclosure_node) {
    # Update the sparkle:dsaSignature attribute
    # Need to use the namespace prefix 'sparkle' when accessing the attribute
    $enclosure_node.SetAttribute("dsaSignature", "http://www.andymatuschak.org/xml-namespaces/sparkle", $generated_hash)

    # Save the modified XML back to the file
    $appcast_xml.Save($appcast_file)
    Write-Host "Appcast file updated with hash."
  } else {
    Write-Host "Error: Could not find the <enclosure> node in $appcast_file to update the signature."
    # Decide if you want to break here or continue without updating the hash
    # break
  }

}


# Step 9: Update version in appcast.xml (line 15 - assuming version is on line 15)
Write-Host "Updating version in $appcast_file..."

Write-Host "App version from pubspec.yaml: $app_version"

# Read the appcast file line by line again before modifying line 15
$appcast_lines = Get-Content $appcast_file
# Modify the array element for line 15 (index 14)
# This assumes the version is within a sparkle:version="X.Y.Z" attribute on line 15
$appcast_lines[14] = $appcast_lines[14] -replace 'sparkle:version="[^"]*"', "sparkle:version=`"$app_version`""
# Write the modified content back to the appcast file
Set-Content $appcast_file $appcast_lines
Write-Host "Appcast file updated with version."