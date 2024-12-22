<#
CommConsole by Androsh7
https://github.com/Androsh7/CommConsole

MIT License

Copyright (c) 2024 Androsh7

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

[string] $prompt = ">"

# Transmitter
[string] $dst_ip = ""
[int] $dst_port = 0
[string] $dst_proto = ""
[int] $transmitter = 0

function Start_UDP_Transmitter {
    try {
        # Credit for Transmitter Socket Code: Thomas Lee - tfl@psp.co.uk - http://www.pshscripts.blogspot.com 
        $global:dst_ip = Read-Host "Destination IP"
        $global:dst_port = [int](Read-Host "Destination Port")
        $global:dst_proto = "(UDP)"

        $Address = [system.net.IPAddress]::Parse($dst_ip)

        # Create IP Endpoint
        $End = New-Object System.Net.IPEndPoint $address, $dst_port

        # Create Socket
        $saddrf = [System.Net.Sockets.AddressFamily]::InterNetwork
        $Stype = [System.Net.Sockets.SocketType]::Dgram
        $Ptype = [System.Net.Sockets.ProtocolType]::UDP
        $global:Sock = New-Object System.Net.Sockets.Socket $saddrf, $stype, $ptype

        # Connect to socket
        $global:sock.Connect($End)

        # Mark transmitter as working
        $global:transmitter = 1
        
        Write-Host "Successfully started the UDP transmitter" -ForegroundColor Blue
        $global:prompt = "${dst_ip}:${dst_port} ${dst_proto}>"
    }
    catch {
        Write-Host "ERROR: could not setup UDP transmitter" -ForegroundColor Red
        $global:transmitter = $false
        $global:dst_ip = ""
        $global:dst_port = 0
        $global:dst_proto = ""
        $global:prompt = ">"
    }

}
function Stop_UDP_Transmitter {
    try {
        $global:sock.Close()
        $global:transmitter = $false
        $global:dst_ip = ""
        $global:dst_port = 0
        $global:dst_proto = ""
        $global:prompt = ">"
        Write_Host "Successfully closed the UDP transmitter" -ForegroundColor Blue
    }
    catch {
        Write-Host "ERROR: could not stop UDP transmitter" -ForegroundColor Red
        $global:transmitter = $false
        $global:prompt = ">"
    }
}

# Receiver
$convo_file = "conversations.txt"

# This is the code that opens in another window
$UDP_Receiver = {
    $port = Read-Host "Select the UDP Listening Port"
    $port = [int]$port
    $udpClient = New-Object System.Net.Sockets.UdpClient($port) # Create a UDP client
    $udpClient.Client.ReceiveTimeout = 1000 # Set a timeout for receiving data (optional)
    $remoteEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0) # Create a remote endpoint to hold the sender's information
    Clear-Host
    Write-Host "---------------------- UDP_LISTENER on port ${port} ----------------------" -ForegroundColor Blue
    while ($true) {
        try {
            $receiveBytes = $udpClient.Receive([ref]$remoteEndPoint) # Receive a datagram 
            $receivedData = [Text.Encoding]::ASCII.GetString($receiveBytes) # Convert the received byte array to a string
            Write-Host "Received data: $receivedData" # Print the received data to the console
        } catch {}
    }
    
    # Optionally close the UDP client when exiting the loop
    $udpClient.Close()
}

# interprets commands starting with "#"
function UserCommands {
    param (
        $UserInput
    )
    switch ($UserInput) {
        # Command Menu
        "#help" { 
            Write-Host "#help - opens the help menu
#udp_start - begins the udp transmitter
#udp_stop - stops the udp transmitter
#udp_listener- opens a udp listener window
#info - gives info on the transmitter
#test - tests the current transmitter
#set_file - designates a file to store the conversation
#clear_file - clears the conversation file
#read_file - opens a terminal that reads the conversation
#quit - exits the program and closes the socket" -ForegroundColor Green
        }
        # setup the udp transmitter
        "#udp_start" {
            Start_UDP_Transmitter
        }
        # close the udp transmitter
        "#udp_end" {
            Stop_UDP_Transmitter
        }
        # opens a udp listener window
        "#udp_listen" {
            Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile", "$UDP_Receiver"
        }
        # prints the transmission info
        "#info" {
            Write-Host "Dest IP: ${dst_ip}" -ForegroundColor Green
            Write-Host "Dest Port: ${dst_port}" -ForegroundColor Green
            Write-Host "Protocol: ${proto}" -ForegroundColor Green
        }
        # tests the connection to the target
        "#test" {
        }
        # setup the save file
        "#set_file" {
        }
        # clear the conversation file
        "#clear_file" {
            Out-File $convo_file
        }
        # open file reader
        "#read_file" {

        }
        # quit program
        "#quit" {
            Exit
        }
        Default { 
            Write-Host "Invalid Command" -ForegroundColor Red
        }
    }
}

# title window
Clear-Host
Write-Host "---------------------- CommConsole ----------------------" -ForegroundColor Blue
Write-Host "---------------------- By Androsh7 ----------------------" -ForegroundColor Blue

try {
    while ($true) {
        $UserInput = Read-Host $global:prompt

        # Runs commands starting with "#"
        if ($UserInput -imatch "^#") { 
            UserCommands($UserInput) 
        }

        # If the transmitter is setup, attempt to transmit the message
        elseif ($transmitter) {
            # Create encoded buffer
            $Enc = [System.Text.Encoding]::ASCII
            $Buffer = $Enc.GetBytes($UserInput)

            # Send the buffer via the established socket
            $Sent = $global:Sock.Send($Buffer)

            # Informational message for length
            $length = $UserInput.Length
            $date = Get-Date -UFormat "%m/%d/%Y %R UTC%Z"
            Write-Host "SENT ${length} Characters AT ${date}" -ForegroundColor Green
            
            # writes to the conversation file
            Out-File $convo_file -Append -InputObject "----- SENT TO ${dst_ip}:${dst_port} ${dst_proto} AT ${date} -----"
            Out-File $convo_file -Append -InputObject $UserInput
        }

        # If the transmitter is not setup, give an error
        else {
            Write-Host "ERROR: no working transmitter" -ForegroundColor Red
        }
    }
} finally {
    Write-Host "Goodbye!" -ForegroundColor Green
}