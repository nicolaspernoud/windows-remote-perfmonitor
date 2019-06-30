# Get usages as jobs
$env:WhereAmI = $PSScriptRoot
$gpuUsageJob = Start-Job -ScriptBlock { Get-Counter -Counter "\GPU Engine(*3d*)\Utilization Percentage" -Continuous }
$cpuUsageJob = Start-Job -ScriptBlock { 
    $processor = Get-PerformanceCounterLocalName 238
    $percentProcessorTime = Get-PerformanceCounterLocalName 6
    Get-Counter "\$processor(0)\$percentProcessorTime" -Continuous 
} -InitializationScript { Import-Module "$env:WhereAmI\utils.psm1" }

# Http Server
$http = [System.Net.HttpListener]::new() 

# Hostname and port to listen on
$http.Prefixes.Add("http://localhost:8080/")

# Start the Http Server 
$http.Start()

# Log ready message to terminal 
if ($http.IsListening) {
    write-host " HTTP Server Ready!  " -f 'black' -b 'gre'
    write-host "try testing the different route examples: " -f 'y'
    write-host "Display dashboard : $($http.Prefixes)" -f 'y'
    write-host "API: $($http.Prefixes)api" -f 'y'
}

# Init results
$gpuResult = 0
$cpuResult = 0

# INFINITE LOOP
# Used to listen for requests
while ($http.IsListening) {

    # Get Request Url
    # When a request is made in a web browser the GetContext() method will return a request object
    # Our route examples below will use the request object properties to decide how to respond
    $context = $http.GetContext()

    # API - http://127.0.0.1/api
    if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/api') {

        # We can log the request to the terminal
        write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'
    
        # Get GPU Data
        $tempResult = $gpuResult
        $gpuResult = 0
        Try {
            $gpuJobResults = (Receive-Job -Job $gpuUsageJob)
            foreach ($val in $gpuJobResults[$gpuJobResults.Length - 1].Readings.Split("`n")) {
                $numVal = 0
                $isNum = [System.Double]::TryParse($val, [ref]$numVal)
                $gpuResult += $numVal
            }
        }
        Catch {
            $gpuResult = $tempResult
        }
    
        # Get CPU Data
        $tempResult = $cpuResult
        $cpuResult = 0
        Try {
            $cpuJobResults = (Receive-Job -Job $cpuUsageJob)
            foreach ($val in $cpuJobResults[$cpuJobResults.Length - 1].Readings.Split("`n")) {
                $numVal = 0
                $isNum = [System.Double]::TryParse($val, [ref]$numVal)
                $cpuResult += $numVal
            }
        }
        Catch {
            $cpuResult = $tempResult
        }
    
        # the html/data you want to send to the browser
        # you could replace this with: [string]$html = Get-Content "C:\some\path\index.html" -Raw
        [string]$html = "{`"GPU_usage`":$($gpuResult),`"CPU_usage`":$($cpuResult)}"
            
        # Respond to the request
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert htmtl to bytes
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
        $context.Response.OutputStream.Close() # close the response
        
    }

    # Web App - http://127.0.0.1/
    elseif ($context.Request.HttpMethod -eq 'GET') {

        # We can log the request to the terminal
        write-host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'

        # the html/data you want to send to the browser
        # you could replace this with: [string]$html = w
        if ($context.Request.RawUrl -eq '/') {
            [string]$html = Get-Content "$PSScriptRoot/index.html" -Raw
        }
        else {
            [string]$html = Get-Content "$PSScriptRoot$($context.Request.RawUrl)" -Raw
        }
        
        #resposed to the request
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert htmtl to bytes
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to broswer
        $context.Response.OutputStream.Close() # close the response
    
    }
} 