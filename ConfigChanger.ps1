param([string]$file = $null, [bool]$skipCheck = $false, [bool]$showSkipped = $true, [bool]$autoClose = $false);
Clear-Host;

if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") { 
    $runPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition;
}
else { 
    $runPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]);
}

[bool]$validFile = $false;

do {
    if ([string]::IsNullOrEmpty($file)) {
        $file = (Read-Host -Prompt "File Path").Trim();
    }
    if (!(Test-Path -Path $file)) {
        if (Test-Path -Path "$runPath\$file") {
            $file = "$runPath\$file";
            $validFile = $true;
        }
        else {
            Write-Output 'File was not found.';
            $temp = Read-Host -Prompt 'Try again? (Y/N)';
            if ($temp.ToLower() -eq 'n' -or $temp.ToLower() -eq 'no') {
                Write-Output 'Exit command received.';
                if (!$autoclose) {
                    Read-Host -Prompt "Press Enter to exit";
                }
                exit;
            }
            $file = '';
        }
    }
    else { 
        $validFile = $true;
    }
} while ($validFile -eq $false);

try {
    $json = Get-Content -path $file -Raw -ErrorAction Stop;
    $changesObj = ConvertFrom-Json $json -ErrorAction Stop;
}
catch {
    Write-Output 'Broken JSON file detected.';
    if (!$autoclose) {
        Read-Host -Prompt "Press Enter to exit";
    }
    exit;
}

if ([string]::IsNullOrEmpty($changesObj.MinecraftDirectory)) {
    if (!$autoclose) {
        Write-Output 'No Minecraft Directory defined in file. Verify path and try agian.';
    }
    exit;
}

$countFile = $changesObj.Changes.Count;
$countEdits = 0;
foreach ($item in $changesObj.Changes) {
    $countEdits += $item.edits.count;
}
$directory = $changesObj.MinecraftDirectory;
Write-Output "Loaded File: $file";
Write-Output "Path: $directory";
Write-Output "-------------------------------------";
Write-Output "Expecting $countFile file(s) to be modified with $countEdits possible edit(s)";
Write-Output "-------------------------------------";

if (!$skipCheck) {
    $continue = Read-Host -Prompt 'Continue? (Y/N)';
    if ($continue.ToLower() -eq 'n' -or $continue.ToLower() -eq 'no') {
        Write-Output 'Exit command received.';
        if (!$autoclose) {
            Read-Host -Prompt "Press Enter to exit";
        }
        exit;
    }
}

Write-Output '';

if ($null -ne $changesObj -and $changesObj.Changes) {
    $current = 1;
    foreach ($change in $changesObj.Changes) {
        $path = "$directory\$($change.File)";
        if (Test-Path -Path $path) {
            $tempContent = get-content -Path $path -Raw;
            Write-Output '--------------------------';
            Write-Output "[$current/$countFile] $($change.name) - $($change.file)";
            Write-Output '--------------------------';

            foreach ($edit in $change.edits) {
                if ($edit.enabled -eq $true) {
                    if ($tempContent -match $edit.find) {
                        $tempcontent = $tempContent.replace($edit.find, $edit.replace);
                        Write-Output "'$($edit.find)' Changed to '$($edit.replace)' - Done";
                    }
                    else {
                        if ($tempContent -match $edit.replace) {
                            if ($showSkipped) {
                                Write-Output "'$($edit.find)' to '$($edit.replace)' - Skipped: Value already set";
                            }
                        }
                        else {
                            if ($showSkipped) {
                                Write-Output "'$($edit.find)' to '$($edit.replace)' - Skipped: Pattern not found";
                            }
                        }
                    }
                }
                else {
                    if ($showSkipped) {
                        Write-Output "'$($edit.find)' to '$($edit.replace)' - Skipped: is disabled";
                    }
                }
            }
            Set-Content -path $path -Value $tempContent;
            Write-Output '';
        }
        else {
            Write-Output '--------------------------';
            Write-Output "[$current/$countFile] File: '$($change.File)' was not found, Skipping.";
            Write-Output '--------------------------';
            Write-Output '';
        }
        $current++;
    }
}

Write-Output "`n";
if (!$autoclose) {
    Read-Host -Prompt "Press Enter to exit";
}
exit;