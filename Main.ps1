##### Script made by Spadge1989 aka. Padge ######
#################################################
##### You do not need to change any of the variables below unless you need to change their default values
##### The menu will allow you to change variables from within the script.

##### Default Variables ###########

# Variable for Service
$serviceName = 'SplunkForwarder'

# Default location of File/Folder to be deleted
$fileInput = "\d$\Program Files\SplunkUniversalForwarder\var\lib\splunk\fishbucket"

# Array Variable setup for holding lists for errors.
$computersDown = @()
$computerServiceCantStop = @()
$computerServiceNotPresent = @()
$computerServiceCantStart = @()
$computerFishBucketDeletionFailed = @()
$computerServiceCantStartBack = @()

###### End of Default Variables ############

###### Functions ##########

# Function to select file with popup browse window
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "CSV (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

# Function use to start up remote service
# This function first checks that the host is online and responding to pings.
# It then checks if the service is actually installed 
# It then checks to see if the service is actually stopped first

Function Service-Start
{
    $computerServiceCantStart = @()
    $inputfile = Get-FileName "C:\"
    $computers = get-content $inputfile
    ForEach ($currentComputer in $computers)
    {
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
        Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
        Write-Host "Checking $serviceName status on computer $currentComputer" -ForegroundColor Yellow
        $serviceStatus = Get-Service -Computer $currentComputer -Name $serviceName -erroraction 'silentlycontinue' -ErrorVariable ServiceError
        if($ServiceError)
        {
            Write-Host "$currentComputer does not appear to have the $serviceName installed" -ForegroundColor Red
            $computerServiceNotPresent += "`n$currentComputer"
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
                                $computerServiceCantStart += "`n$currentComputer"
                                break
                            }
                    }
            }
        }
        else
        {
            Write-Host "$currentComputer is Down" -ForegroundColor Red
            $computersDown += "`n$currentComputer"
        }
    }
}


# Function to stop remote Service
# This function firsly uses ping to ensure it can actually connect to the endpoint
# Then it checks that the service is actually present before attempting to stop that service. If this is unsucceesful the script tries a few times
# before skipping it and adding it to the computerServiceCantStop List

Function Service-Stop
{
    $computerServiceCantStop = @()
    $inputfile = Get-FileName "C:\"
    $computers = get-content $inputfile
    ForEach ($currentComputer in $computers)
    {
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
        Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
        Write-Host "Checking $serviceName status on computer $currentComputer" -ForegroundColor Yellow
        $serviceStatus = Get-Service -Computer $currentComputer -Name $serviceName -erroraction 'silentlycontinue' -ErrorVariable ServiceError
        if($ServiceError)
        {
            Write-Host "$currentComputer does not appear to have the $serviceName installed" -ForegroundColor Red
            $computerServiceNotPresent += "`n$currentComputer"
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
        }
        else
        {
            Write-Host "$currentComputer is Down" -ForegroundColor Red
            $computersDown += "`n$currentComputer"
        }
    }
}


# Function to restart Service - It is a stop followed by a start to ensure it stop / starts it properly.
# Not an easy way to check if the restart command completed succesfully!

Function Service-Restart
{
    $computerServiceCantStop = @()
    $inputfile = Get-FileName "C:\"
    $computers = get-content $inputfile
    ForEach ($currentComputer in $computers)
    {
        if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
        {        
        Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
        Write-Host "Checking $serviceName status on computer $currentComputer" -ForegroundColor Yellow
        $serviceStatus = Get-Service -Computer $currentComputer -Name $serviceName -erroraction 'silentlycontinue' -ErrorVariable ServiceError
        if($ServiceError)
        {
            Write-Host "$currentComputer does not appear to have the $serviceName installed" -ForegroundColor Red
            $computerServiceNotPresent += "`n$currentComputer"
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
                $computerServiceCantStartBack = @()
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
                                $computerServiceCantStartBack += "`n$currentComputer"
                                break
                            }
                    }
            }
        }
        else
        {
            Write-Host "$currentComputer is Down" -ForegroundColor Red
            $computersDown += "`n$currentComputer"
        }
    }
}

# Function for the Menu
Function User-Menu
{
    param 
    (
        [string]$Title = 'Menu'
    )
    cls
Write-Host "`n################################################"
Write-Host "################################################"
Write-Host "#### Script made by Spadge1989 - aka. Padge ####"
Write-Host "##### This project can be found on GitHub ######"
Write-Host "############ github.com/spadge1989 #############"
Write-Host "################################################"
Write-Host "################################################`n"
Write-Host "================ $Title ================`n"
Write-Host "Note: When you select an option that requires a list of computers`nyou will be prompted to select the CSV file (MUST be a .csv file)`n"
Write-Host "This script can be used to do the following depending on the options you select:`n"
Write-Host "1. Review/Change the default settings such as service names & file/folder locations."
Write-Host "2. Start Service on remote windows machines within the same domain."
Write-Host "3. Stop Service on remote windows machines within the same domain."
Write-Host "4. Restart Service on remote windows machines within the same domain."
Write-Host "5. Delete File/Folder on remote windows machines within the same domain."
Write-Host "6. Stop Service, Delete File/Folder & Start Service back up."
Write-Host "9. Print Results"
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
Write-Host "1. Change Service. Currently: $serviceName"
Write-Host "2. Change File/Folder to be deleted on remote computers. Currently: $fileInput"
Write-Host "3. TBC"
Write-Host "4. TBC"
Write-Host "5. TBC"
Write-Host "6. TBC"
Write-Host "7. TBC"
Write-Host "8. TBC"
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
                            Write-Host "====== Change Service Name ======`n"
                            Write-Host "Current Service Name set to: $serviceName"
                            Write-Host "This must be the actualy ServiceName as displayed in the Name filed in Services.msc not the display name`n"
                            $serviceName = Read-Host -Prompt "Please enter new service name"
                        }
                        '2'
                        {
                            cls
                            Write-Host "====== Change File Input ======`n"
                            Write-Host "Current Location set to: $fileInput"
                            Write-Host "To enter new file / folder location for remote system you have to remove the leading computer name"
                            Write-Host "e.g. C:\Program Files\SomeRandomProgram\RandomFolderOrFile = \c`$\Program Files\SomeRandomProgram\RandomFolderOrFile`n"
                            $fileInput = Read-Host -Prompt "Enter New Location"
                        }
                        '3'
                        {
                            cls
                            'You chose Sub-option #3'
                        }
                        '4'
                        {
                            cls
                            'You chose Sub-option #4'
                        }
                        '5'
                        {
                            cls
                            'You chose Sub-option #5'
                        }
                        '6'
                        {
                            cls
                            'You chose Sub-option #6'
                        }
                        '7'
                        {
                            cls
                            'You chose Sub-option #8'
                        }
                        '8'
                        {
                            cls
                            'You chose Sub-option #8'
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
                cls 
                Service-Start
           }
           '3'
           { 
                cls 
                Service-Stop
           }
           '4'
           { 
                cls 
                'You chose option #4' 


           }
           '5'
           { 
                cls 
                'You chose option #5' 


           }
           '6'
           { 
                cls 
                'You chose option #6' 


           }
           'q' 
           { 
                Write-Host "Thanks, goodbye"
                return
           } 
     } 
     pause 
} 
until ($input -eq 'q') 

############# End of Main Menu ###############


###### Computer list parameters / execution ########

# get input csv files using the Function Get-FileName
$inputfile = Get-FileName "C:\"
$computers = get-content $inputfile
# File locations plus the Current computer settings put together with the fileInput (default or specificed by user)
$file = "\\$currentComputer" + "$fileInput"

##### End of computer list parameters 


### Main script running  ####
ForEach ($currentComputer in $computers)
{
    # initial stopping of running services / check if service is present / detected & if host is actualy online via ping
    if(Test-Connection -BufferSize 32 -Count 1 -ComputerName $currentComputer -Quiet) 
    {        
        Write-Host "$currentComputer Online, continuing script" -ForegroundColor Green
        Write-Host "Checking $serviceName status on computer $currentComputer" -ForegroundColor Yellow
        $serviceStatus = Get-Service -Computer $currentComputer -Name $serviceName -erroraction 'silentlycontinue' -ErrorVariable ServiceError
        if($ServiceError)
        {
            Write-Host "$currentComputer does not appear to have the $serviceName installed" -ForegroundColor Red
            $computerServiceNotPresent += "`n$currentComputer"
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
                        Stop-Service $serviceName
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
        
            # Once the service has been confirmed to be stopped continue script - Deletion of the fishbucket
            if($serviceStatus.Status -eq "Stopped")
            {
                Write-Host "$serviceName on $currentComputer is Stopped, continuing script" -ForegroundColor Green
                # Delete FishBucket
                if (test-path -path $file)
                {
                    Write-Host "FishBucket Detected on $currentComputer, attempting to delete" -ForegroundColor Yellow
                    Remove-Item $file -force -recurse
                    Start-Sleep -seconds 10
                    while (test-path -path $file)
                    {
                        Write-Host "FishBucket on $currentComputer failed to be deleted, attempting again" -ForegroundColor Yellow
                        Remove-Item $file -force -recurse
                        Start-Sleep -seconds 10
                        if (!(test-path -path $file))
                        {
                            break
                        }
                        $b+=1
                        if($b -gt 3)
                        {
                            Write-Host "Failed to delete FishBucket on $currentComputer, skipping" -ForegroundColor Red
                            $computerFishBucketDeletionFailed += "`n$currentComputer"
                            break
                        }
                    }
                }
                if (!(test-path $file))
                {
                    Write-Host "FishBucket on $currentComputer succesfully deleted / not present, continuing" -ForegroundColor Green
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
                                    $computerServiceCantStart += "`n$currentComputer"
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
            Write-Host "$currentComputer is Down" -ForegroundColor Red
            $computersDown += "`n$currentComputer"
        }
        Write-Host "Script Completed"
        Write-Host "========================================"
}
if ($computersDown)
{
    Write-Host "List of Computers that did not respond to a Ping (appeared offline - suggest trying these seperate/manually): $computersDown" -ForegroundColor Red
}
if ($computerServiceNotPresent)
{
    Write-Host "List of Computers that did not appear to have the service installed: $computerServiceNotPresent" -ForegroundColor Red
}
if ($computerServiceCantStop)
{
    Write-Host "List of Computers where the $serviceName service could not be stopped: $computerServiceCantStop" -ForegroundColor Red
}
if ($computerFishBucketDeletionFailed)
{
    Write-Host "List of Computers where the FishBucket could not be deleted but is present ($serviceName service will remain offline): $computerFishBucketDeletionFailed" -ForegroundColor Red
}
if ($computerServiceCantStart)
{
    Write-Host "List of Computers where the $serviceName service could not be started back up after succesfully deleting the FishBucket: $computerServiceCantStart" -ForegroundColor Red
}
