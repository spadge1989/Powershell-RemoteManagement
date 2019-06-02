##### Script made by Spadge1989 aka. Padge ######
#################################################
##### You do not need to change any of the variables below unless you need to change their default values
##### The menu will allow you to change variables from within the script.

##### Default Variables ###########

# Variable for Service
$serviceName = ""

# Default location of File/Folder to be deleted
$fileInput = ""

# Clearing of some Variables to make sure they are blank to start

$computers = ""
$localMSIPackage = ""
$inputfilemsi = ""
$inputfile = ""
$LocalMSIPacageFile = ""
$destinationLocation = ""
$taskStatus = ""

# Array Variable setup for holding lists for errors.
$computersDown = @()
$computerServiceCantStop = @()
$computerServiceNotPresent = @()
$computerServiceCantStart = @()
$computerFileDeletionFailed = @()
$computerServiceCantStartBack = @()
$computerTaskInstallFalied = @()
$computerTaskInstallPrevious = @()
$computerTaskCleanupFailed = @()

###### End of Default Variables ############

###### Functions ##########

# Function to select file with popup browse window

Function Get-FileName($initialDirectory)
{
    Write-Host "`nSelect the csv list that contains the computers you wish to run this against`n"
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog  
    $OpenFileDialog.Title = "Select List of computers File"   
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "CSV (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

# Same as function above but used for the MSI selection in the local system

Function Get-FileNameMSIPackage($initialDirectory)
{
    Write-Host "`nSelect the MSI you wish to install on the endpoints on the local Machine`n"
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog  
    $OpenFileDialog.Title = "Select MSI Package"   
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "MSI (*.msi)| *.msi"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

# Function use to start up remote service
# This function first checks that the host is online and responding to pings.
# It then checks if the service is actually installed 
# It then checks to see if the service is actually stopped first

Function Service-Start
{
    $script:computerServiceCantStart = @()
    ForEach ($currentComputer in $computers)
    {
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
        Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
        Write-Host "Checking $serviceName status on computer $currentComputer" -ForegroundColor Yellow
        $script:serviceStatus = Get-Service -Computer $currentComputer -Name $serviceName -erroraction 'silentlycontinue' -ErrorVariable ServiceError
        if($ServiceError)
        {
            Write-Host "$currentComputer does not appear to have the $serviceName installed" -ForegroundColor Red
            $script:computerServiceNotPresent += "`n$currentComputer"
         }   
            # when computer is confirmed online check the services of that computer & start if required 
            if($serviceStatus.Status -eq "Stopped")
            {
                Write-Host "$currentComputer Service is Stopped, Starting $serviceName" -ForegroundColor Yellow
                Start-Service -InputObject $serviceStatus
                Start-Sleep -seconds 5
                $serviceStatus.Refresh()
                $a = 0
                    # check if the service actually stopped and attempt to shut the service down 5 times with 10 seconds in between each attempt
                    while ($serviceStatus.Status -ne 'Running')
                    {                    
                        write-host "$serviceName on $currentComputer still Stopped, attempting to start again" -ForegroundColor Yellow
                        Start-Service -InputObject $serviceStatus
                        Start-Sleep -seconds 10
                        $serviceStatus.Refresh()
                            if($serviceStatus.Status -eq 'Running')
                            {
                                break
                            }
                            $a+=1
                            if($a -gt 3)
                            {
                                write-host "$serviceName could not be started, skipping $currentComputer" -ForegroundColor Red
                                $script:computerServiceCantStart += "`n$currentComputer"
                                break
                            }
                    }
            }
            if($serviceStatus.Status -eq "Running")
            {
                Write-Host "$currentComputer Service is Already Running" -ForegroundColor Green
            }
        }
        else
        {
            Write-Host "$currentComputer is Down / Not responding to Pings, Skipping" -ForegroundColor Red
            $script:computersDown += "`n$currentComputer"
        }
    }
    Write-Host "Script has completed, Press Enter to display the results"
    pause
    Results
}


# Function to stop remote Service
# This function firsly uses ping to ensure it can actually connect to the endpoint
# Then it checks that the service is actually present before attempting to stop that service. If this is unsucceesful the script tries a few times
# before skipping it and adding it to the computerServiceCantStop List

Function Service-Stop
{
    $script:computerServiceCantStop = @()
    ForEach ($currentComputer in $computers)
    {
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
        Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
        Write-Host "Checking $serviceName status on computer $currentComputer" -ForegroundColor Yellow
        $script:serviceStatus = Get-Service -Computer $currentComputer -Name $serviceName -erroraction 'silentlycontinue' -ErrorVariable ServiceError
        if($ServiceError)
        {
            Write-Host "$currentComputer does not appear to have the $serviceName installed" -ForegroundColor Red
            $script:computerServiceNotPresent += "`n$currentComputer"
         }   
            # when computer is confirmed online check the services of that computer & stop if required 
            if($serviceStatus.Status -eq "Running")
            {
                Write-Host "$currentComputer Service is Running, stopping $serviceName" -ForegroundColor Yellow
                Stop-Service -InputObject $serviceStatus
                Start-Sleep -seconds 5
                $serviceStatus.Refresh()
                $a = 0
                    # check if the service actually stopped and attempt to shut the service down 5 times with 10 seconds in between each attempt
                    while ($serviceStatus.Status -ne 'Stopped')
                    {                    
                        write-host "$serviceName on $currentComputer still Running, attempting to stop again" -ForegroundColor Yellow
                        Stop-Service -InputObject $serviceStatus
                        Start-Sleep -seconds 10
                        $serviceStatus.Refresh()
                            if($serviceStatus.Status -eq 'Stopped')
                            {
                                break
                            }
                            $a+=1
                            if($a -gt 3)
                            {
                                write-host "$serviceName could not be stopped, skipping $currentComputer" -ForegroundColor Red
                                $script:computerServiceCantStop += "`n$currentComputer"
                                break
                            }
                    }
            }
            if($serviceStatus.Status -eq "Stopped")
            {
                Write-Host "$currentComputer Service is Already Stopped" -ForegroundColor Green
            }
        }
        else
        {
            Write-Host "$currentComputer is Down / Not responding to Pings, Skipping" -ForegroundColor Red
            $script:computersDown += "`n$currentComputer"
        }
    }
    Write-Host "Script has completed, Press Enter to display the results"
    pause
    Results
}


# Function to restart Service - It is a stop followed by a start to ensure it stop / starts it properly.
# Not an easy way to check if the restart command completed succesfully!

Function Service-Restart
{
    $script:computerServiceCantStop = @()
    ForEach ($currentComputer in $computers)
    {
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
        Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
        Write-Host "Checking $serviceName status on computer $currentComputer" -ForegroundColor Yellow
        $script:serviceStatus = Get-Service -Computer $currentComputer -Name $serviceName -erroraction 'silentlycontinue' -ErrorVariable ServiceError
        if($ServiceError)
        {
            Write-Host "$currentComputer does not appear to have the $serviceName installed" -ForegroundColor Red
            $script:computerServiceNotPresent += "`n$currentComputer"
         }   
            # when computer is confirmed online check the services of that computer & stop if required 
            if($serviceStatus.Status -eq "Running")
            {
                Write-Host "$currentComputer Service is Running, stopping $serviceName" -ForegroundColor Yellow
                Stop-Service -InputObject $serviceStatus
                Start-Sleep -seconds 5
                $serviceStatus.Refresh()
                $a = 0
                    # check if the service actually stopped and attempt to shut the service down 5 times with 10 seconds in between each attempt
                    while ($serviceStatus.Status -ne 'Stopped')
                    {                    
                        write-host "$serviceName on $currentComputer still Running, attempting to stop again" -ForegroundColor Yellow
                        Stop-Service -InputObject $serviceStatus
                        Start-Sleep -seconds 10
                        $serviceStatus.Refresh()
                            if($serviceStatus.Status -eq 'Stopped')
                            {
                                break
                            }
                            $a+=1
                            if($a -gt 3)
                            {
                                write-host "$serviceName could not be stopped, skipping $currentComputer" -ForegroundColor Red
                                $computerServiceCantStop += "`n$currentComputer"
                                break
                            }
                    }
            }
            if($serviceStatus.Status -eq "Stopped")
            {
                $script:computerServiceCantStartBack = @()
                Write-Host "$currentComputer Service is Stopped, Starting $serviceName" -ForegroundColor Yellow
                Start-Service -InputObject $serviceStatus
                Start-Sleep -seconds 5
                $serviceStatus.Refresh()
                $a = 0
                    # check if the service actually started and attempt to start the service 5 times with 10 seconds in between each attempt
                    while ($serviceStatus.Status -ne 'Running')
                    {                    
                        write-host "$serviceName on $currentComputer still Stopped, attempting to start again" -ForegroundColor Yellow
                        Start-Service -InputObject $serviceStatus
                        Start-Sleep -seconds 10
                        $serviceStatus.Refresh()
                            if($serviceStatus.Status -eq 'Running')
                            {
                                break
                            }
                            $a+=1
                            if($a -gt 3)
                            {
                                write-host "$serviceName could not be started back up, skipping $currentComputer" -ForegroundColor Red
                                $script:computerServiceCantStartBack += "`n$currentComputer"
                                break
                            }
                    }
            }
        }
        else
        {
            Write-Host "$currentComputer is Down / Not responding to Pings, Skipping" -ForegroundColor Red
            $script:computersDown += "`n$currentComputer"
        }
    }
    Write-Host "Script has completed, Press Enter to display the results"
    pause
    Results
}

# Function to only delete remote file and check it was done

Function Delete-File
{
    $script:computerFileDeletionFailed = @()
    $script:file = "\\$currentComputer" + "$fileInput"

    ForEach ($currentComputer in $computers)
    {
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
            Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
            if (test-path -path $file)
            {
                Write-Host "File/Folder Detected on $currentComputer, attempting to delete" -ForegroundColor Yellow
                Remove-Item $file -force -recurse
                Start-Sleep -seconds 10
                while (test-path -path $file)
                {
                    Write-Host "File/Folder on $currentComputer failed to be deleted, attempting again" -ForegroundColor Yellow
                    Remove-Item $file -force -recurse
                    Start-Sleep -seconds 10
                    if (!(test-path -path $file))
                    {
                        Write-Host "File/Folder on $currentComputer succesfully deleted / not present, continuing" -ForegroundColor Green
                        break
                    }
                    $b+=1
                    if($b -gt 3)
                    {
                        Write-Host "Failed to delete File/Folder on $currentComputer, skipping" -ForegroundColor Red
                        $script:computerFileDeletionFailed += "`n$currentComputer"
                        break
                    }
                }
            }
        }
        else
        {
            Write-Host "$currentComputer is Down / Not responding to Pings, Skipping" -ForegroundColor Red
            $script:computersDown += "`n$currentComputer"
        }
    }
    Write-Host "Script has completed, Press Enter to display the results"
    pause
    Results
}

# Function to Delete remote file/folder with a service stop / started on windows machines via domain hidden shared (e.g. c$)
# This first stops the remote service, then deletes the file then starts the service back up

Function Delete-File-With-Service-Restart
{
    $script:computerFileDeletionFailed = @()
    $script:file = "\\$currentComputer" + "$fileInput"

    ForEach ($currentComputer in $computers)
    {
        # initial stopping of running services / check if service is present / detected & if host is actualy online via ping
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
            Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
            Write-Host "Checking $serviceName status on computer $currentComputer" -ForegroundColor Yellow
            $script:serviceStatus = Get-Service -Computer $currentComputer -Name $serviceName -erroraction 'silentlycontinue' -ErrorVariable ServiceError
            if($ServiceError)
            {
                Write-Host "$currentComputer does not appear to have the $serviceName installed" -ForegroundColor Red
                $script:computerServiceNotPresent += "`n$currentComputer"
            }   
            # when computer is confirmed online check the services of that computer & stop if required 
            if($serviceStatus.Status -eq "Running")
            {
                Write-Host "$currentComputer Service is Running, stopping $serviceName" -ForegroundColor Yellow
                Stop-Service -InputObject $serviceStatus
                Start-Sleep -seconds 5
                $serviceStatus.Refresh()
                $a = 0
                    # check if the service actually stopped and attempt to shut the service down 5 times with 10 seconds in between each attempt
                    while ($serviceStatus.Status -ne 'Stopped')
                    {                    
                        write-host "$serviceName on $currentComputer still Running, attempting to stop again" -ForegroundColor Yellow
                        Stop-Service -InputObject $serviceStatus
                        Start-Sleep -seconds 10
                        $serviceStatus.Refresh()
                            if($serviceStatus.Status -eq 'Stopped')
                            {
                                break
                            }
                            $a+=1
                            if($a -gt 3)
                            {
                                write-host "$serviceName could not be stopped, skipping $currentComputer" -ForegroundColor Red
                                $script:computerServiceCantStop += "`n$currentComputer"
                                break
                            }
                    }
            }        
        
            # Once the service has been confirmed to be stopped continue script - Deletion of the fishbucket
            if($serviceStatus.Status -eq "Stopped")
            {
                Write-Host "$serviceName on $currentComputer is Stopped, continuing script" -ForegroundColor Green
                # Delete File/Folder
                if (test-path -path $file)
                {
                    Write-Host "File/Folder Detected on $currentComputer, attempting to delete" -ForegroundColor Yellow
                    Remove-Item $file -force -recurse
                    Start-Sleep -seconds 10
                    while (test-path -path $file)
                    {
                        Write-Host "File/Folder on $currentComputer failed to be deleted, attempting again" -ForegroundColor Yellow
                        Remove-Item $file -force -recurse
                        Start-Sleep -seconds 10
                        if (!(test-path -path $file))
                        {
                            Write-Host "File/Folder on $currentComputer succesfully deleted / not present, continuing" -ForegroundColor Green
                            break
                        }
                        $b+=1
                        if($b -gt 3)
                        {
                            Write-Host "Failed to delete File/Folder on $currentComputer, skipping" -ForegroundColor Red
                            $script:computerFileDeletionFailed += "`n$currentComputer"
                            break
                        }
                    }
                }
                if (!(test-path $file))
                {
                    Write-Host "File/Folder on $currentComputer succesfully deleted / not present, continuing" -ForegroundColor Green
                    # Resume service after deletion
                    if($serviceStatus.Status -eq "Stopped")
                    {
                    Write-Host "$currentComputer Service is Stopped, starting back up $serviceName" -ForegroundColor Yellow
                    Start-Service -InputObject $serviceStatus
                    Start-Sleep -seconds 5
                    $serviceStatus.Refresh()
                    $c = 0
                        # check if the service actually started and attempt to start the service down 5 times with 10 seconds in between each attempt
                        while ($serviceStatus.Status -ne 'Running')
                        {                    
                            write-host "$serviceName on $currentComputer still not started, attempting to start again" -ForegroundColor Yellow
                            Stop-Service $serviceName
                            Start-Sleep -seconds 10
                            $serviceStatus.Refresh()
                                if($serviceStatus.Status -eq 'Running')
                                {
                                    break
                                }
                                $c+=1
                                if($c -gt 3)
                                    {
                                    write-host "$serviceName could not be Started back up, skipping $currentComputer" -ForegroundColor Red
                                    $script:computerServiceCantStart += "`n$currentComputer"
                                    break
                                }
                        }
                    }
                    if($serviceStatus.Status -eq "Running")
                    {
                        write-host "Succesfully started back up $serviceName on $currentComputer" -ForegroundColor Green
                    }
                }
            }
        }
        # Used if the endpoint cannot be connected to
        else
        {
            Write-Host "$currentComputer is Down / Not responding to Pings, Skipping" -ForegroundColor Red
            $script:computersDown += "`n$currentComputer"
        }
    }
    Write-Host "Script has completed, Press Enter to display the results"
    pause
    Results
}

# Function to install MSI packagae remotely using Scheduled tasks (schtasks.exe)

Function Task-Install
{
    $script:computerTaskInstallFalied = @()
    $script:computerTaskInstallPrevious = @()
    $script:computerTaskCleanupFailed = @()
    $script:LocalMSIPacageFile = Split-Path $inputfilemsi -leaf
    ForEach ($currentComputer in $computers)
    {
        $script:destinationLocation = "\\" + "$currentComputer" + "\c`$\" + "$LocalMSIPacageFile"
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
            Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
            Write-Host "Attempting to copy the MSI package from $inputfilemsi to $destinationLocation" -ForegroundColor Yellow
            # Check if the file already exists first - if it doesnt attempt to copy the file
            if (test-path -path $destinationLocation)
            {
                Write-Host "$LocalMSIPacageFile File appears to already be present on $currentComputer, What would you like to do:" -ForegroundColor Yellow
                Write-Host "1. Remove the File, re-add it and continue with install."
                Write-Host "2. Skip this computer & add it to the install Failure List"
                $input = Read-Host "Please make a selection"
                switch ($input)
                {
                    '1'
                    {
                        Remove-Item $destinationLocation -force -recurse | Out-Null
                        
                        if (!(test-path -path $destinationLocation))
                        {
                            Write-Host "Succesfully removed $inputfilemsi, continuing with script" -ForegroundColor Green
                        }
                        else
                        {
                            Write-Host "Could not delete the file for some reason, Skipping $currentComputer" -ForegroundColor Red
                            $script:computerTaskInstallFalied += "`n$currentComputer"
                        }
                    }
                    '2'
                    {
                        Write-Host "$currentComputer Skipped"
                        $script:computerTaskInstallFalied += "`n$currentComputer"
                        Return
                    }                    
                }                 
            }
            if (!(test-path -path $destinationLocation))
            {
                copy-item -Path "$inputfilemsi" -Destination "$destinationLocation"| Out-Null 
                if (test-path -path $destinationLocation)
                {
                    Write-Host "$LocalMSIPacageFile Succesfully copied to $currentComputer, Initiating the install process" -ForegroundColor Green
                    #$taskCheck = schtasks.exe /query /s "$currentComputer" /v /tn "$LocalMSIPacageFile"
                    schtasks.exe /query /s "$currentComputer" /v /tn "$LocalMSIPacageFile" *> $null
                    if ($?)
                    {
                        Write-Host "$LocalMSIPacageFile Task already appears to be installed on $currentComputer" -ForegroundColor Yellow
                        Write-Host "Attempting to remove this Task" -ForegroundColor Yellow
                        schtasks.exe /delete /S "$currentComputer" /TN "$LocalMSIPacageFile" /F | Out-Null
                        schtasks.exe /query /s "$currentComputer" /v /tn "$LocalMSIPacageFile" *> $null
                        if (!($?))
                        {  
                        }
                        else 
                        {
                            Write-Host "Unable to delete the task, skipping $currentComputer" -ForegroundColor Red
                            $script:computerTaskInstallFalied += "`n$currentComputer"
                        }
                    }
                    schtasks.exe /query /s "$currentComputer" /v /tn "$LocalMSIPacageFile" *> $null
                    if (!($?))
                    {
                        Write-Host "$LocalMSIPacageFile Task Not Present on $CurrentComputer adding task" -ForegroundColor Green
                        schtasks.exe /create /RU "SYSTEM" /S "$currentComputer" /sc once /sd 01/01/1901 /st 23:59 /TN "$LocalMSIPacageFile" /TR "msiexec.exe /i C:\$LocalMSIPacageFile AGREETOLICENSE=Yes /quiet" | Out-Null
                        schtasks.exe /query /s "$currentComputer" /v /tn "$LocalMSIPacageFile" *> $null
                        if ($?)
                        {
                            Write-Host "$LocalMSIPacageFile task on $currentComputer added succesfully, attemtping to run this task" -ForegroundColor Green
                            schtasks.exe /run /s "$currentComputer" /tn "$LocalMSIPacageFile" | Out-Null
                            Write-Host "Run command sent to $currentComputer to execute $LocalMSIPacageFile Task, checking status" -ForegroundColor Yellow
                            while ($taskStatus -ne "0")
                            {
                                start-sleep -seconds 10
                                $taskStatus = ((schtasks /query /S "$currentComputer" /v /TN "$LocalMSIPacageFile")[4] -split ' +')[7]
                                if ($taskStatus -eq "267009")
                                {
                                    Write-Host "$LocalMSIPacageFile on $currentComputer is running, waiting for completion" -ForegroundColor Yellow
                                }
                                elseif ($taskStatus -eq "267011")
                                {
                                    Write-Host "$LocalMSIPacageFile on $currentComputer Error in starting the task, attempting to correct" -ForegroundColor Yellow
                                    schtasks.exe /run /s "$currentComputer" /tn "$LocalMSIPacageFile" | Out-Null
                                }
                                elseif ($taskStatus -eq "1603")
                                {
                                    Write-Host "$LocalMSIPacageFile on $currentComputer appears to have already been installed in the past, skipping installation, begining cleanup" -ForegroundColor Yellow
                                    $script:computerTaskInstallPrevious += "`n$currentComputer"
                                    Remove-Item $destinationLocation -force -recurse | Out-Null
                                    if (!(test-path -path $destinationLocation))
                                    {
                                        Write-Host "Succesfully removed $inputfilemsi, continuing with script" -ForegroundColor Green
                                    }
                                    else
                                    {
                                        Write-Host "Could not delete the file for some reason, Skipping $currentComputer" -ForegroundColor Red
                                        $script:computerTaskCleanupFailed += "`n$currentComputer"
                                    }
                                    schtasks.exe /delete /S "$currentComputer" /TN "$LocalMSIPacageFile" /F | Out-Null
                                    schtasks.exe /query /s "$currentComputer" /v /tn "$LocalMSIPacageFile" *> $null
                                    if (!($?))
                                    {
                                        Write-Host "Succesfully removed $LocalMSIPacageFile Task, continuing with script" -ForegroundColor Green
                                    }
                                    else
                                    {
                                        Write-Host "Could not delete the $LocalMSIPacageFile Task for some reason, Skipping $currentComputer" -ForegroundColor Red
                                        if ($computerTaskCleanupFailed -match $currentComputer)
                                        {
                                            Write-Host "$currentComputer Already been added to the Cleanup Failed list, skipping this step" -ForegroundColor Yellow
                                        }
                                        else
                                        {
                                            $script:computerTaskCleanupFailed += "`n$currentComputer"
                                        }
                                    }
                                    break
                                }
                                elseif ($taskStatus -eq "0")
                                {
                                    Write-Host "$LocalMSIPacageFile on $currentComputer appears to have run succesfully" -ForegroundColor Green
                                    Write-Host "Cleaning up package from $destinationLocation"
                                    Remove-Item $destinationLocation -force -recurse | Out-Null
                                    if (!(test-path -path $destinationLocation))
                                    {
                                        Write-Host "Succesfully removed $inputfilemsi, continuing with script" -ForegroundColor Green
                                    }
                                    else
                                    {
                                        Write-Host "Could not delete the file for some reason, Skipping $currentComputer" -ForegroundColor Red
                                        $script:computerTaskCleanupFailed += "`n$currentComputer"
                                    }
                                    schtasks.exe /delete /S "$currentComputer" /TN "$LocalMSIPacageFile" /F | Out-Null
                                    schtasks.exe /query /s "$currentComputer" /v /tn "$LocalMSIPacageFile" *> $null
                                    if (!($?))
                                    {
                                        Write-Host "Succesfully removed $LocalMSIPacageFile Task, continuing with script" -ForegroundColor Green
                                    }
                                    else
                                    {
                                        Write-Host "Could not delete the $LocalMSIPacageFile Task for some reason, Skipping $currentComputer" -ForegroundColor Red
                                        if ($computerTaskCleanupFailed -match $currentComputer)
                                        {
                                            Write-Host "$currentComputer Already been added to the Cleanup Failed list, skipping this step" -ForegroundColor Yellow
                                        }
                                        else
                                        {
                                            $script:computerTaskCleanupFailed += "`n$currentComputer"
                                        }
                                    }
                                    break
                                }
                            }

                        }
                        else 
                        {
                            Write-Host "$LocalMSIPacageFile task on $currentComputer added unsuccesfully for unknown reason, skipping ths computer" -ForegroundColor Red
                            $script:computerTaskInstallFalied += "`n$currentComputer"
                        }
                    }
                }
                else 
                {
                    Write-Host "$LocalMSIPacageFile Failed to be copied to $currentComputer for unknown reason, skipping" -ForegroundColor Red
                    $script:computerTaskInstallFalied += "`n$currentComputer"
                }

            }
            else 
            {
                Write-Host "something went wrong with $currentComputer, Skipping"  -ForegroundColor Red
                $script:computerTaskInstallFalied += "`n$currentComputer"
            }
        }
        else
        {
            Write-Host "$currentComputer is Down / Not responding to Pings, Skipping" -ForegroundColor Red
            $script:computersDown += "`n$currentComputer"
        }
    }
    Write-Host "Script has completed, Press Enter to display the results"
    pause
    Results
}

# Function to list Results - this just lists out from the arrays

Function Results
{
    cls
    Write-Host "`n================================ Results ===============================`n"
    Write-Host "====== Note: These are cleared each time another option is selected ======"
    Write-Host "==========================================================================`n"
    if (!($computerTaskCleanupFailed) -AND !($computersDown) -AND !($computerServiceNotPresent) -AND !($computerServiceCantStop) -AND !($computerFileDeletionFailed) -AND !($computerServiceCantStart) -AND !($computerServiceCantStartBack) -AND !($computerTaskInstallFalied) -AND !($computerTaskInstallPrevious))
    {
        Write-Host "`n No Hosts Failed - Either nothing has been run or all is good `n`n======================================"  -ForegroundColor Green
    }
    if ($computersDown)
    {
        Write-Host "List of Computers that did not respond to a Ping (appeared offline - suggest trying these seperate/manually):`n$computersDown`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
    if ($computerServiceNotPresent)
    {
        Write-Host "List of Computers that did not appear to have the service installed:`n$computerServiceNotPresent`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
    if ($computerServiceCantStop)
    {
        Write-Host "List of Computers where the $serviceName service could not be stopped:`n$computerServiceCantStop`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
    if ($computerFileDeletionFailed)
    {
        Write-Host "List of Computers where the FishBucket could not be deleted but is present ($serviceName service will remain offline):`n$computerFileDeletionFailed`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
    if ($computerServiceCantStart)
    {
        Write-Host "List of Computers where the $serviceName service could not be started back up after succesfully deleting the FishBucket:`n$computerServiceCantStart`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
    if ($computerServiceCantStartBack)
    {
        Write-Host "List of Computers that the Restart command was issued to but the service could not be started back up after a succesful Stop was issued to that computer:`n$computerServiceCantStartBack`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
    if ($computerTaskInstallFalied)
    {
        Write-Host "List of Computers that the Installation of the MSI package failed:`n$computerTaskInstallFalied`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
    if ($computerTaskInstallPrevious)
    {
        Write-Host "List of Computers that the Installation of the MSI package appears to have already been done previously:`n$computerTaskInstallPrevious`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
    if ($computerTaskCleanupFailed)
    {
        Write-Host "List of Computers that the Installation Succeded but the MSI package / Task was unable to be deleted after it ran (I Suggest checking this):`n$computerTaskCleanupFailed`n`n==================END-OF-LIST==================`n" -ForegroundColor Red
    }
}


# Function for the Main-Menu
Function User-Menu
{
        param
        (
        [string]$Title = 'Menu'
        )
        cls
        Write-Host "`n################################################"-ForegroundColor Green
        Write-Host "################################################"-ForegroundColor Green
        Write-Host "#### Script made by Spadge1989 - aka. Padge ####"-ForegroundColor Green
        Write-Host "##### This project can be found on GitHub ######"-ForegroundColor Green
        Write-Host "############ github.com/spadge1989 #############"-ForegroundColor Green
        Write-Host "################################################"-ForegroundColor Green
        Write-Host "################################################`n"-ForegroundColor Green
        Write-Host "================ $Title ================`n"
        Write-Host "Note: When you select an option that requires a list of computers`nyou will be prompted to select the CSV file (MUST be a .csv file)`n"
        Write-Host "This script can be used to do the following depending on the options you select:`n"
        Write-Host "1. Review/Change the settings such as service names & file/folder locations."
        Write-Host "2. Start Service on remote windows machines within the same domain."
        Write-Host "3. Stop Service on remote windows machines within the same domain."
        Write-Host "4. Restart Service on remote windows machines within the same domain."
        Write-Host "5. Delete File/Folder on remote windows machines within the same domain."
        Write-Host "6. Stop Service, Delete File/Folder & Start Service back up."
        Write-Host "7. --ALPHA PHASE Install MSI Package to remote machines. ALPHA PHASE (report bugs please)--"
        Write-Host "9. Print Results - Will only print failures - Results reset after every single option is ran other than option 1."
        Write-Host "Q: Quit`n"    
}

# Function for option 1.Sub-Menu

Function 1Sub-Menu
{
    param 
    (
        [string]$Title = 'Option 1 Sub-Menu'
    )
    cls
Write-Host "`n================ $Title ================`n"
Write-Host "1. Change/Select Service. Currently: $serviceName"
Write-Host "2. Change/Select File/Folder to be deleted on remote computers. Currently: $fileInput"
Write-Host "3. Change/Select Computer List. Currently: $inputfile"
Write-Host "4. Change File/Folder to be deleted on remote computers. Currently: $inputfilemsi"
Write-Host "Q: Main Menu`n"
}

# Function for sub menu 1
Function Sub-Menu-Options1
{
                do
                {
                    1Sub-Menu
                    $input = Read-Host "Please make a selection"
                    switch ($input)
                    {

                        '1'
                        {
                            cls
                            Write-Host "`n====== Change/Select Service ======`n"
                            Write-Host "Current Service Name set to: $serviceName"
                            Write-Host "This must be the actualy ServiceName as displayed in the Name filed in Services.msc not the display name`n"
                            $script:serviceName = Read-Host -Prompt "Please enter new service name"
                        }
                        '2'
                        {
                            cls
                            Write-Host "`n====== Change/Select File/Folder ======`n"
                            Write-Host "Current Location set to: $fileInput"
                            Write-Host "To enter new file / folder location for remote system you have to remove the leading computer name"
                            Write-Host "e.g. C:\Program Files\SomeRandomProgram\RandomFolderOrFile = \c`$\Program Files\SomeRandomProgram\RandomFolderOrFile`n"
                            $script:fileInput = Read-Host -Prompt "Enter New Location"
                        }
                        '3'
                        {
                            cls
                            Write-Host "`n====== Change/Select Computer List ======`n"
                            Write-Host "Current Location set to: $inputfile"
                            pause
                            $script:inputfile = Get-FileName "C:\"
                            if ($inputfile -ne "")
                            {
                            $script:computers = get-content $inputfile
                            }
                            else
                            {
                                Write-Host "Cancled by user" -ForegroundColor Red
                            }
                        }
                        '4'
                        {
                            cls
                            Write-Host "`n====== Change File/Folder to be deleted on remote computers ======`n"
                            Write-Host "Current Location set to: $inputfilemsi"
                            pause
                            $script:inputfilemsi = Get-FileNameMSIPackage "C:\"
                            if ($inputfilemsi -ne "")
                            {
                                $script:localMSIPackage = get-content $inputfilemsi
                            }
                            else
                            {
                                Write-Host "Cancled by user" -ForegroundColor Red
                            }
                        }
                        'q'
                        {
                            cls
                        }
                    }
                    
                }
                until ($input -eq 'q')
}

############# End of Functions ################

############# Main Menu Do loop ###############
do 
{ 
    User-Menu 
    $input = Read-Host "Please make a selection" 
    switch ($input) 
    { 
        '1' 
        {
            cls
            Sub-Menu-Options1
        }
        '2' 
        {
            if (!($inputfile))
            {
                $script:inputfile = Get-FileName "C:\"
                if ($inputfile -ne "")
                {
                $script:computers = get-content $inputfile
                }
                else
                {
                    Write-Host "Cancled by user" -ForegroundColor Red
                }
            }
            if (!($serviceName))
            {
                $script:serviceName = Read-Host -Prompt "Service name currently blank - Please enter service name"
            }
            if (($serviceName) -AND ($inputfile))
            {
                cls 
                Service-Start
            }
            else 
            {
                Write-Host "You need to enter a service name, list of endpoint to run this against."
                Write-Host "You will be returned to the main menu now."
                pause
            }
        }
        '3'
        {
            if (!($inputfile))
            {
                $script:inputfile = Get-FileName "C:\"
                if ($inputfile -ne "")
                {
                $script:computers = get-content $inputfile
                }
                else
                {
                    Write-Host "Cancled by user" -ForegroundColor Red
                }
            }
            if (!($serviceName))
            {
                Write-Host "This must be the actualy ServiceName as displayed in the Name filed in Services.msc not the display name"
                $script:serviceName = Read-Host -Prompt "Service name currently blank - Please enter service name"
            }
            if (($serviceName) -AND ($inputfile))
            {
            cls 
            Service-Stop
            }
            else 
            {
                Write-Host "You need to enter a service name & list of endpoint to run this against."
                Write-Host "You will be returned to the main menu now."
                pause
            }
        }
        '4'
        {
            if (!($inputfile))
            {
                $script:inputfile = Get-FileName "C:\"
                if ($inputfile -ne "")
                {
                $script:computers = get-content $inputfile
                }
                else
                {
                    Write-Host "Cancled by user" -ForegroundColor Red
                }
            }
            if (!($serviceName))
            {
                Write-Host "This must be the actualy ServiceName as displayed in the Name filed in Services.msc not the display name"
                $script:serviceName = Read-Host -Prompt "Service name currently blank - Please enter service name"
            }
            if (($serviceName) -AND ($inputfile))
            {
            cls 
            Service-Restart
            }
            else 
            {
                Write-Host "You need to enter a service name & list of endpoint to run this against."
                Write-Host "You will be returned to the main menu now."
                pause
            }
        }
        '5'
        {
            if (!($inputfile))
            {
                $script:inputfile = Get-FileName "C:\"
                if ($inputfile -ne "")
                {
                $script:computers = get-content $inputfile
                }
                else
                {
                    Write-Host "Cancled by user" -ForegroundColor Red
                }
            }
            if (!($fileInput))
            {
                Write-Host "To enter new file / folder location for remote system you have to remove the leading computer name"
                Write-Host "e.g. C:\Program Files\SomeRandomProgram\RandomFolderOrFile = \c`$\Program Files\SomeRandomProgram\RandomFolderOrFile`n"
                $script:fileInput = Read-Host -Prompt "Enter file location to be deleted Location"
            }
            if (($fileInput) -AND ($inputfile))
            {
            cls
            Delete-File
            }
            else 
            {
                Write-Host "You need to enter a File location to be deleted & list of endpoint to run this against."
                Write-Host "You will be returned to the main menu now"
                pause
            }
        }
        '6'
        { 
            if (!($inputfile))
            {
                $script:inputfile = Get-FileName "C:\"
                if ($inputfile -ne "")
                {
                $script:computers = get-content $inputfile
                }
                else
                {
                    Write-Host "Cancled by user" -ForegroundColor Red
                }
            }
            if (!($serviceName))
            {
                Write-Host "This must be the actualy ServiceName as displayed in the Name filed in Services.msc not the display name"
                $script:serviceName = Read-Host -Prompt "Service name currently blank - Please enter service name"
            }
            if (!($fileInput))
            {
                Write-Host "To enter new file / folder location for remote system you have to remove the leading computer name"
                Write-Host "e.g. C:\Program Files\SomeRandomProgram\RandomFolderOrFile = \c`$\Program Files\SomeRandomProgram\RandomFolderOrFile`n"
                $script:fileInput = Read-Host -Prompt "Enter file location to be deleted Location"
            }
            if (($serviceName) -AND ($fileInput) -AND ($inputfile))
            {
            cls 
            Delete-File-With-Service-Restart
            }
            else 
            {
                Write-Host "You need to enter a service name, File location & list of endpoint to run this against."
                Write-Host "You will be returned to the main menu now"
                pause
            }
        }
        '7'
        { 
            if (!($inputfile))
            {
                $script:inputfile = Get-FileName "C:\"
                if ($inputfile -ne "")
                {
                $script:computers = get-content $inputfile
                }
                else
                {
                    Write-Host "Cancled by user" -ForegroundColor Red
                }
            }
            if(!($inputfilemsi))
            {
                $script:inputfilemsi = Get-FileNameMSIPackage "C:\"
                if ($inputfilemsi -ne "")
                {
                    $script:localMSIPackage = get-content $inputfilemsi
                }
                else
                {
                    Write-Host "Cancled by user" -ForegroundColor Red
                }
            }
            if (($inputfilemsi)-AND ($inputfile))
            {
            cls 
            Task-Install
            }
            else 
            {
                Write-Host "You need to enter a list of endpoint to run this against & the select the MSI you wish to install from the local machine."
                Write-Host "You will be returned to the main menu now"
                pause
            } 
        }
        '9'
        { 
            cls
            Results 
        }
        'q' 
        { 
            Write-Host "Thanks, goodbye"
            return
        }
    }      
} 
until ($input -eq 'q')

############# End of Main Menu ###############