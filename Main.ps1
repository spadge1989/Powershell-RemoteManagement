# setting up the enviroment for prompt box
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "CSV (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

# get input csv files
$inputfile = Get-FileName "C:\"
$computers = get-content $inputfile

# service name shiz
$serviceName = 'SplunkForwarder'

# Where the file/Folder is located that you would like to be deleted (\\$currentComputer\c$\ should always remain the same - only change the bit after this)
$fileInput = "Program Files\SplunkUniversalForwarder\var\lib\splunk\fishbucket"

# Main script to do services on endpoints
$computersDown = @()
$computerServiceCantStop = @()
$computerServiceNotPresent = @()
$computerServiceCantStart = @()
$computerFishBucketDeletionFailed = @()

Write-Host "Would you like to change the service name - currently $serviceName"
    $serviceRead = Read-Host " ( y / n ) (default n) " 
    Switch ($serviceRead) 
     { 
       Y {$serviceName = Read-Host -Prompt "Please enter new service name"} 
       N {} 
       Default {} 
     }

Write-Host "Would you like to change the file/folder location that gets deleted - currently $fileInput"
    $fileRead = Read-Host " ( y / n ) (default n) " 
    Switch ($fileRead) 
     { 
       Y {$fileInput = Read-Host -Prompt "Please enter new File/Folder & path you require to be deleted removing the leading \ `n(e.g. c:\Program Files\randomProgram\folderToBeDeleted = Program Files\randomProgram\folderToBeDeleted)"} 
       N {} 
       Default {} 
     }

$file = "\\$currentComputer\d$\" + "$fileInput"

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
