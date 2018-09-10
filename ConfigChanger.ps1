param([string]$file = $null, [bool]$skipCheck = $false, [bool]$showSkipped = $true, [bool]$autoClose = $false);
Clear-Host;

function Write-Note($find, $replace, $message) {
    write-Output "'$find' to '$replace' - $message";
}

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

if ([string]::IsNullOrEmpty($changesObj.MinecraftDirectory) -or !(Test-Path -path $changesObj.MinecraftDirectory)) {
    if (!$autoclose) {
        Write-Output 'No or invalid Minecraft Directory defined in file. Verify path and try agian.';
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
$total = New-Object -TypeName psobject;
$total | Add-Member -MemberType NoteProperty -Name 'Changed' -Value 0;
$total | Add-Member -MemberType NoteProperty -Name 'Skipped' -Value 0;
$total | Add-Member -MemberType NoteProperty -Name 'Disabled' -Value 0;
$total | Add-Member -MemberType NoteProperty -Name 'AlreadySet' -Value 0;
$total | Add-Member -MemberType NoteProperty -Name 'FileNotFound' -Value 0;
$total | Add-Member -MemberType NoteProperty -Name 'EditNotFound' -Value 0;

if ($null -ne $changesObj -and $changesObj.Changes) {
    $current = 1;
    foreach ($change in $changesObj.Changes) {
        $editCount = $change.edits.count;
        $enabledCount = 0;
        Write-Output '--------------------------';
        Write-Output "[$current/$countFile] $($change.name) - $($change.file)";

        if ($editCount -gt 0) {
            $enabledCount = ($change.edits | Where-Object { $_.enabled -eq $true} | Measure-Object).count;
            Write-Output "$enabledCount of $editCount edits are enabled";
        }
        else {
            Write-Output "No edits were found.";
        }
        Write-Output '--------------------------';

        if ($editCount -gt 0 -and $enabledCount -gt 0) {
            $path = "$directory\$($change.File)";
            if (Test-Path -Path $path) {
                $tempContent = get-content -Path $path -Raw;
                [bool]$hasChanges = $false;
                foreach ($edit in $change.edits) {
                    [bool]$found = $false;
                    if ($edit.enabled -eq $true) {
                        $edit.method;
                        if ($null -eq $edit.method -or 'indexof' -eq ($edit.method).toLower()) {
                            $index = $tempContent.IndexOf($edit.find);
                            if ($index -ge 0) { 
                                $tempContent = $tempContent.Replace($edit.find, $edit.replace);
                                $found = $true; 
                            } 
                        }
                        elseif ('regex' -eq ($edit.method).toLower()) {
                            if ($tempContent -match $edit.find) {
                                $tempcontent = $tempContent -replace $($edit.find), $($edit.replace);
                                $found = $true; 
                            }
                        }
                        else {
                            Write-Note -find $edit.find -replace $edit.replace -message "Skipped: method not recognized";
                            $total.skipped++;
                        }
                        
                        if ($found -eq $true) {
                            Write-Note -find $edit.find -replace $edit.replace -message "Done";
                            $total.changed++; 
                            $hasChanges = $true;
                        }
                        else {
                            $index = $tempContent.IndexOf($edit.replace);
                            if ($index -gt 0) {
                                if ($showSkipped) {
                                    Write-Note -find $edit.find -replace $edit.replace -message "Skipped: Value already set";
                                }
                                $total.alreadyset++;
                            }
                            else {
                                if ($showSkipped) {
                                    Write-Note -find $edit.find -replace $edit.replace -message "Skipped: Pattern not found";
                                }
                                $total.editnotfound++;
                            }
                        }
                    }
                    else {
                        if ($showSkipped) {
                            Write-Note -find $edit.find -replace $edit.replace -message "Skipped: is disabled";
                        }
                        $total.disabled++;
                    }
                }
                if ($hasChanges -eq $true) {
                    Set-Content -path $path -Value $tempContent;
                }
                Write-Output '';
            }
            else {
                Write-Output "File: '$($change.File)' was not found, Skipping.";
                Write-Output '--------------------------';
                Write-Output '';
                $total.Filenotfound++;
            }
        } elseif ($editCount -gt 0) {
            $total.disabled += $editCount;
        }
        $current++;
    }
}

Write-Output '';
if (!$autoclose) {
    Write-Output 'Totals:';
    Write-Output '--------------------------';
    Write-Output $total;
    Read-Host -Prompt "Press Enter to exit";
}
exit;