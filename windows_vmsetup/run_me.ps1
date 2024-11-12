
param (
    [bool]$do_ignore = $true
)

$setup_program_name = "windows_setup.ps1"
$python_invokation = ""

$list_of_languages_needed = @(
    @{
        program   = "python";
        arguments = "--version"
    } #Probably going to need more in the future
)

$list_of_programs_needed = @(
    "vscode";
    "sysinternals";
    "processHacker"
)

function check_installation {
    param (
        [string]$command,
        [string[]]$arguments = @()
    )

    try {
        $process = Start-Process -FilePath $command -ArgumentList $arguments -NoNewWindow -PassThru -Wait -ErrorAction Stop

        if ($process.ExitCode -ne 0) {
            Write-Host "Failed to execute: $command with arguments $arguments"
            return $false
        }
    } catch {
        Write-Host "Failed to execute: $_"
        return $false        
    }

    return $true
}

function check_if_setup_file_exists {
    $setup_file_path = $setup_program_name
    if (Test-Path -Path $setup_file_path) {
        Write-Host "The file '$setup_file_path' exists in the same directory."
    } else {
        Write-Host "The file '$setup_file_path' does not exist in the same directory."
        Write-Host "Attempting to download from github/dadn2002"
        try {
            Clear-DnsClientCache
            Invoke-WebRequest -OutFile windows_setup.ps1 -Uri https://raw.githubusercontent.com/dadn2002/my_macros/main/windows_vmsetup/windows_setup.ps1
            Write-Host "Downloaded with success"
        } catch {
            Write-Host "Failed to download setup file"
            return $false
        }
    }

    return $true
}

function do_cleanup {
    Write-Host "Removing $setup_program_name from directory"
    try {
        Remove-Item -Path (Join-Path "..\" $setup_program_name)
    } catch {
        Write-Host "Failed to remove $setup_program_name with error $_"
    }
    Write-Host "Exiting program"
}

function check_if_program_exists {
    param (
        [string]$program,
        [string]$arguments
    )

    if ($arguments -eq "") {
        $arguments = " "
    }
    $is_installed = check_installation -command $program -arguments $arguments
    
    if ($is_installed -eq $false) {
        Write-Host "$program is not installed, attempting to do it"
        
        $fullPath = Join-Path -Path (Get-Location) -ChildPath $setup_program_name

        Write-Host "Running setup from: $fullPath with args $program"
        if (Test-Path $fullPath) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-File $fullPath $program" -NoNewWindow -Wait -ErrorAction Stop
        } else {
            Write-Host "The setup program was not found: $fullPath"
        }

        $install_success = check_installation -command $program -arguments $arguments
        
        if ($install_success -eq $false) {
            Write-Host "Failed to setup $program"
            return $false
        }

        return $true
    }

    Write-Host "$program is already installed"
    return $true
    
}

function install_python_requirements {
    try {
        & pip install -r "requirements.txt"
        Write-Host "pip install -r requirements finished with success"
    } catch{
        Write-Host "Failed to install python requirements.txt"
        return $false
    }

    return $true
}

function check_python_installation {
    $pythonCommands = @("python"; "python3"; "py"; "py3")
    
    foreach ($cmd in $pythonCommands) {
        try {
            # Try running the command with --version to check if it's available
            $output = & $cmd --version 2>&1

            # Check if the output contains version info
            if ($output -match "Python\s+\d+\.\d+\.\d+") {
                Write-Host "Python is installed. Command '$cmd' works."
                return $cmd
            }
        } catch {
            Write-Host "Command '$cmd' not found, trying next."
        }
    }

    Write-Host "No Python command found."
    return $null
}

function download_repo_locally {
    Invoke-WebRequest -Uri https://github.com/dadn2002/system_monitor/archive/refs/heads/main.zip -OutFile main.zip
    $destinationFolder = Get-Location
    Write-Host "destinationFolder $destinationFolder"
    Expand-Archive -Path "main.zip" -DestinationPath "$destinationFolder" -Force
    Remove-Item -Path "main.zip"
    Rename-Item -Path (Join-Path $destinationFolder "system_monitor-main") "system_monitor"
    Set-Location -Path (Join-Path $destinationFolder "system_monitor")
    Write-Host "$destinationFolder"
}

function main {
    $setup_script_downloaded = check_if_setup_file_exists
    if ($setup_script_downloaded -eq $false) {
        Write-Host "Failed to find/download setup file, closing program"
        return $false
    }

    foreach ($things_we_might_need in $list_of_languages_needed) {
        check_if_program_exists -program $things_we_might_need.program -arguments $things_we_might_need.arguments > $null
    }

    if ($do_ignore -eq $false) {
        foreach ($programs_we_need in $list_of_programs_needed){
            Start-Process -FilePath $setup_program_name -ArgumentList $programs_we_need -NoNewWindow -Wait -ErrorAction Stop
        }
    }

    # update path variables
    #$env:Path = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
    
    Write-Host "Clonning the repo locally"
    download_repo_locally
    
    $pip_success = install_python_requirements # You cant place functions inside comparations
    if ($pip_success -eq $false) {
        return 0 > $null
    }

    $python_invokation = check_python_installation
    Write-Host "Python Invokation found as $python_invokation"

    Write-Host "Success installing dependences for python execution"
    
    do_cleanup

    pause
    Write-Host "Attempt to execute the programs for the first time"
    & $python_invokation "extract_data.py"
    & $python_invokation "main.py"

    
}

Clear-Host 
main