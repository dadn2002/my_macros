
param (
	[string]$install_that = $args[0]
)


function DownloadResponse {
	param (
		[bool]$status,
		[string]$method,
		[string]$output
	)
	if ($status) {
		Write-Host "File Downloaded via $method to: $output"
	} else {
		Write-Host "$method failed"
		Write-Host "Error: $_"
	}
}

function DownloadFile {
	param (
		[string]$url,
		[string]$file_name
	)

	$output_path = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads", $file_name)
	Write-Host "output_path: $output_path"
	if (Test-Path -Path $output_path) {
		Write-Host "Setup is already installed"
		return $output_path
	}
	Write-Host "Could not find file in $output_path, trying to download"
	# return $output_path # Remember to remove this line
	# Im thankfull for the comment purge that happened

	$methods = @(
		@{Name = "Invoke-WebRequest"; Command = {Invoke-WebRequest -Uri $url -OutFile $output_path -ErrorAction Stop}},
		@{Name = "curl"; Command = {curl -o $output_path $url}},
		@{Name = "wget"; Command = {wget $url -OutFile $output_path}},
		@{Name = "Invoke-WebRequest -UseBasicParsing"; Command = {Invoke-WebRequest -Uri $url -OutFile $output_path -ErrorAction Stop -UseBasicParsing}},
		@{Name = "curl -UseBasicParsing"; Command = {curl -o $output_path $url -UseBasicParsing}},
		@{Name = "wget -UseBasicParsing"; Command = {wget $url -OutFile $output_path -UseBasicParsing}}
	)

	$status = $false
    
	foreach ($method in $methods) {
		try {
			& $method.Command
			$status = $true
			DownloadResponse -status $status -method $method.Name -output $output_path
			return $output_path
			break
		} catch {
			$status = $false
			DownloadResponse -status $status -method $method.Name -output $output_path
			Write-Host "Error: $_"
		}
	}

	if (-not $status) {
		Write-Host "All download methods failed."
	}
}

function AddToPath {
	param (
		[System.String]$folderToAdd
	)
	
	$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)

	if ($currentPath -notlike "*$folderToAdd*") {
		$newPath = $currentPath + ";" + $folderToAdd
		
		Start-Sleep -Seconds 2
		[System.Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::User)
		Write-Host "Added $folderToAdd to PATH"
		
		$env:Path = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
	} else {
		Write-Host "$folderToAdd is already in PATH"
	}
}

function UnzipFile {
	param (
		[System.String]$zipPath,
		[System.String]$destinationPath,
		[bool]$doAddToPath
	)
	
	if (Test-Path -Path $destinationPath) {
		Write-Host "Extract file already exists in $destinationPath"
		return
	}

	New-Item -ItemType Directory -Path $destinationPath *>&1 | Out-Null

	try {
		Write-Host "Expanding arquive $zipPath to $destinationPath"
		Expand-Archive -Path $zipPath -DestinationPath $destinationPath -Force *>&1 | Out-Null
		Write-Host "Unzipped $zipPath to $destinationPath"
		if ($doAddToPath) {
			try {
				AddToPath -folderToAdd $destinationPath
				Write-Host "Added $destinationPath to path env successfully"
			} catch {
				Write-Host "Failed to add $destinationPath to path env"
				Write-Host "Error: $_"
			}
		}
	} catch {
		Write-Host "Failed to unzip $zipPath"
		Write-Host "Error: $_"
	}
} 

function InstallationRoutine {
	param (
		[string]$setup_path,
		[string]$command
	)

	try {
		Write-Host "Executing $setup_path with args $command"
        Start-Process -FilePath $setup_path -ArgumentList $command -Wait
        Write-Host "Installation completed for $setup_path"
	} catch {
		Write-Host "Failed to install $setup_path"
		Write-Host "Error: $_"
	}
}

$downloadList = @(
	@{	# python 3.12.2
		Url 				= "https://www.python.org/ftp/python/3.12.2/python-3.12.2-amd64.exe"; 
		OutFileName			= "setup_python.exe"; 
		PreInstallCommand 	= $null;
		InstallCommand 		= "/quiet InstallAllUsers=0 PrependPath=1 -NoNewWindow";
		AddToPath 			= $false;
		ExecuteSetup 		= $true;
		FreeSpaceNeeded 	= 0
	},
	@{ 	# winsdksetup
		Url 				= "https://go.microsoft.com/fwlink/?linkid=2286561";
		OutFileName			= "setup_winsdk.exe";
		PreInstallCommand 	= $null;
		InstallCommand 		= "/quiet /norestart -NoNewWindow";
		AddToPath 			= $false;
		ExecuteSetup 		= $false;
		FreeSpaceNeeded 	= 0
	},
	@{	# visual studio with wdk 
		Url 				= "https://aka.ms/vs/17/release/vs_community.exe";
		OutFileName			= "setup_visualstudio.exe";
		PreInstallCommand 	= $null;
		InstallCommand 		= "--add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.VisualStudioExtension --add Microsoft.VisualStudio.Workload.Universal --includeRecommended --quiet --norestart -NoNewWindow";
		AddToPath 			= $false;
		ExecuteSetup 		= $true;
		FreeSpaceNeeded 	= 20
	},
	@{	# vscode
		Url 				= "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user";
		OutFileName			= "setup_vscode.exe";
		PreInstallCommand 	= $null;
		InstallCommand 		= "/wait /verysilent /norestart /add-to-path -NoNewWindow";
		AddToPath 			= $false;
		ExecuteSetup 		= $true;
		FreeSpaceNeeded 	= 0
	},
	@{	# sysinternals
		Url 				= "https://download.sysinternals.com/files/SysinternalsSuite.zip";
		OutFileName			= "sysinternals.zip";
		PreInstallCommand 	= "unzip";
		InstallCommand 		= "";
		AddToPath 			= $true;
		ExecuteSetup 		= $null;
		FreeSpaceNeeded 	= 0
	},
	@{	# x64dbg
		Url 				= "https://github.com/x64dbg/x64dbg/releases/download/snapshot/snapshot_2024-10-18_19-09.zip";
		OutFileName			= "x32-64dbg.zip";
		PreInstallCommand 	= "unzip";
		InstallCommand 		= "";
		AddToPath 			= $false;
		ExecuteSetup 		= $true;
		FreeSpaceNeeded 	= 0
	},
	@{	# msys2 with gcc/g++ (Need to install them manually)
		Url 				= "https://github.com/msys2/msys2-installer/releases/download/2024-07-27/msys2-x86_64-20240727.exe";
		OutFileName			= "setup_msys2.exe";
		PreInstallCommand 	= "";
		InstallCommand 		= 'in --confirm-command --accept-messages --root "C:/Program Files/msys64"';
		AddToPath 			= $false;
		ExecuteSetup 		= $true;
		DoAfterInstallation = {
			Write-Host "Adding to path"
			AddToPath -folderToAdd "C:/Program Files/msys64"
			Write-Host "Execute: pacman -Syu; pacman -S mingw-w64-x86_64-gcc"
			msys2_shell.cmd -mingw64 #-Wait # Dont think its needed but
		};
		FreeSpaceNeeded 	= 0
	},
	@{	# Process Hacker 2
		Url 				= "https://github.com/winsiderss/si-builds/releases/download/3.1.24305/systeminformer-3.1.24305-canary-setup.exe";
		OutFileName			= "setup_processHacker2.exe";
		PreInstallCommand 	= "";
		InstallCommand 		= "-quiet -norestart";
		AddToPath 			= $false;
		ExecuteSetup 		= $true;
		FreeSpaceNeeded 	= 0
	},
	@{	# Git 
		Url 				= "https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.2/Git-2.47.0.2-64-bit.exe";
		OutFileName			= "git.exe";
		PreInstallCommand 	= "";
		InstallCommand 		= '-ArgumentList "/SILENT" -norestart';
		AddToPath 			= $false;
		ExecuteSetup 		= $true;
		FreeSpaceNeeded 	= 0

	}
)

$ignoreSetups = @(
	"setup_python.exe", 
	"setup_winsdk.exe", 
	"setup_visualstudio.exe", 
	"setup_vscode.exe", 
	"sysinternals.zip", 
	"x32-64dbg.zip", 
	"setup_msys2.exe",
	"setup_processHacker2.exe",
	"git.exe"
)

$executeAfterAll = {
	#winget install --id Git.Git -e --source winget
}

# Check if we are installing something specific, if yes, keep it
if (-not [string]::IsNullOrEmpty($install_that)) {
	#Write-Host "install_that is: $install_that"
	# WHY ITS SO HARD TO FIGURE OUT IF ITS NULL/EMPRY STRING IN THIS LAMGINA OMG
	$ignoreSetups = $ignoreSetups | Where-Object { $_ -notlike "*$install_that*" }
} 

foreach ($downloadParam in $downloadList) {
	$skipInstallation = $false
	foreach ($ignoreSetup in $ignoreSetups) {
		if ($ignoreSetup -eq $downloadParam.OutFileName) {
			$skipInstallation = $true
			break
		}
	}		
	if ($skipInstallation) {
		continue
	}

	Write-Host "Initializing install_setup of $($downloadParam.OutFileName)"
	try {
		$output_path = DownloadFile -url $downloadParam.Url -file_name $downloadParam.OutFileName # System.String besides Download file output var being defined as System.IO.Path
		
		$FreeDiskSpace = (Get-PSDrive C).Free / 1GB
		if ($downloadParam.FreeSpaceNeeded -gt $FreeDiskSpace) {
			Write-Host "Not enough space to install $($downloadParam.OutFileName), need $("{0:F2}" -f $downloadParam.FreeSpaceNeeded) GB"
			continue
		}

		if ($output_path) {
			if ($downloadParam.PreInstallCommand -eq "unzip") {
				$destinationPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop", $downloadParam.OutFileName.Split('.')[0])
				UnzipFile -zipPath $output_path -destinationPath $destinationPath -doAddToPath $downloadParam.AddToPath
				#Remove-Item -Path $output_path -Force
				continue
			}

			if (-not $downloadParam.ExecuteSetup) {
				Write-Host "Configured to not run installer of $($downloadParam.OutFileName)"
				continue
			}

			InstallationRoutine -setup_path $output_path -command $downloadParam.InstallCommand
			if ($downloadParam.DoAfterInstallation) {
				& $downloadParam.DoAfterInstallation
			}
		} else {
			Write-Host "Could not find path to $($downloadParam.OutFileName)"
			Write-Host "Error: $_"
		}
	} catch {
		Write-Host "Failed to download $($downloadParam.OutFileName)"
		Write-Host "Error: $_"
	}
}

foreach ($command in $executeAfterAll) {
	& $command
}

