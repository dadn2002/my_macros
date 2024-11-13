param (
    [bool]$ignore = $false
)

$setup_program_name = "windows_setup.ps1"
Clear-DnsClientCache
$setup_code = Invoke-WebRequest -Uri https://raw.githubusercontent.com/dadn2002/my_macros/main/windows_vmsetup/windows_setup.ps1 -UseBasicParsing
$python_invokation = ""

$list_of_languages_needed = @(
    @{
        program   = "python";
        arguments = "--version"
    } #Probably going to need more in the future
)

$list_of_programs_needed = @(
    #"vscode";
    "sysinternals"
    #"processHacker"
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

function check_if_setup_file_exist
function do_cleanup {
    Write-Host "Removing $setup_program_name from directory"
    try {
        Remove-Item -Path ($setup_program_name)
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

        Write-Host "Running setup from: $setup_program_name with args $program"
        if (Test-Path $setup_program_name) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-File $setup_program_name $program" -NoNewWindow -Wait -ErrorAction Stop
        } else {
            Write-Host "The setup program was not found: $setup_program_name"
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
    Remove-Item -Path (Join-Path "data" "network_data.txt")
    Remove-Item -Path (Join-Path "graphs" "graph.html")
    Write-Host "$destinationFolder"
}

function main {
    if (-not $setup_code) {
        Write-Host "Failed to find/download setup file, closing program"
        return $false
    }

    foreach ($things_we_might_need in $list_of_languages_needed) {
        check_if_program_exists -program $things_we_might_need.program -arguments $things_we_might_need.arguments > $null
    }

    if ($ignore -eq $false) {
        foreach ($programs_we_need in $list_of_programs_needed){
            Start-Process -FilePath "powershell.exe" -ArgumentList "-File $setup_program_name $programs_we_need" -NoNewWindow -Wait -ErrorAction Stop
        }
    }

    # update path variables
    #$env:Path = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
    
    Write-Host "Clonning the repo locally"
    download_repo_locally
    
    Write-Host "Attempting again to install requirements.txt"
    $pip_success = install_python_requirements # You cant place functions inside comparations
    if ($pip_success -eq $false) {
        return 0 > $null
    }

    $python_invokation = check_python_installation
    Write-Host "Python Invokation found as $python_invokation"

    Write-Host "Success installing dependences for python execution"
    
    do_cleanup

    Write-Host "Attempt to execute the programs for the first time"
    & $python_invokation "extract_data.py"
    & $python_invokation "main.py"

    Clear-Host

    Write-Host "Initializing webserver for files download"
    $ip_data = ipconfig; 
    $IPv4 = ($ip_data | Select-String "IPv4 Address" | ForEach-Object { $_.Line -replace "^.:\s" }).Trim(); 
    $IPv6Line = ($ip_data | Select-String "Link-local IPv6 Address" | Select-Object -First 1).Line; 
    $IPv6 = ($IPv6Line -replace "IPv6 Address.?:\s", "").Trim(); 
    Write-Host "IPv4 = $IPv4, IPv6 = $IPv6"

    Write-Host "Download data with:"
    Write-Host "curl http://[$IPv6]:8000/data/network_data.txt"

    IEX "$python_invokation -m http.server"
    
}

Clear-Host 
main
