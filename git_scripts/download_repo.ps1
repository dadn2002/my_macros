param (
    [string]$git_uri = "https://github.com/dadn2002/temporary_repo/archive/refs/heads/main.zip",
    [string]$file_name = "webserver"
)

function try-catch {
    param (
        [string]$command
    )

    try {
        IEX $command
        $command_name = $command.Split(" ")[0]
        Write-Host "$command_name success"
        return $true
    } catch {
        Write-Host "command_name failed"
        return $false
    }
}

$request_response = try-catch -command "Invoke-WebRequest -Uri $git_uri -OutFile $file_name.zip -UseBasicParsing"
if ($request_response -eq $false){
    return
}

$output_path = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop", "coding", "$file_name")
if (Test-Path $output_path){
    $remove_item_response = try-catch -command "Remove-Item -Path $output_path -Recurse"
    if ($remove_item_response -eq $false){
        return
    } 
}

$expand_arquive_response = try-catch -command "Expand-Archive -Path $file_name.zip -DestinationPath $output_path"
if ($expand_arquive_response -eq $false){
    return
}

$segments = $git_uri -split '/'
$generated_folder_name = $segments[4]+"-"+$segments[8].replace('.zip', '')
$generated_folder_path = [System.IO.Path]::Combine($output_path, $generated_folder_name)
$generated_folder_contents = [System.IO.Path]::Combine($generated_folder_path, "*")
#Write-Host $generated_folder_name $generated_folder_path $output_path

$move_items_response = try-catch -command "Move-Item -Path $generated_folder_contents -Destination $output_path"
if ($move_items_response -eq $false) {
    return
}

$remove_item_response = try-catch -command "Remove-item -Path $generated_folder_path"
if ($remove_item_response -eq $false) {
    return
}

$remove_item_response = try-catch -command "Remove-item -Path $file_name.zip"
if ($remove_item_response -eq $false) {
    return
}
