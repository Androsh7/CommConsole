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
$convo_file = "conversations.txt"
$Sock = New-Object System.Net.Sockets.Socket

<# ================================================================= #>
<# ======================= ENCRYPT / DECRYPT ======================= #>
<# ================================================================= #>

# Global variables for encryption
$global:encryption_enabled = $false
$global:encryption_key = "defaultkey"

# Function to enable encryption
function Enable_Encryption {
    if ($global:encryption_key -eq "defaultkey") {
        Write-Host "ERROR: Encryption key not set" -ForegroundColor Red
        return
    }
    $global:encryption_enabled = $true
    Write-Host "Encryption enabled" -ForegroundColor Green
}

# Function to disable encryption
function Disable_Encryption {
    $global:encryption_enabled = $false
    Write-Host "Encryption disabled" -ForegroundColor Green
}

# Function to set encryption key with masked input
function Set_Encryption_Key {
    $Key = Read-Host "Enter encryption key" -AsSecureString
    $global:encryption_key = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Key))
    Write-Host "Encryption key set" -ForegroundColor Green
}

# Encryption function
function Encrypt_XOR_Message {
    param (
        [string] $Message
    )
    $Encrypted = ""
    for ($i = 0; $i -lt $Message.Length; $i++) {
        $Encrypted += [char]($Message[$i] -bxor $global:encryption_key[$i % $global:encryption_key.Length])
    }
    return $Encrypted
}

function Decrypt_XOR_Message {
    param (
        [string] $Message
    )
    $Decrypted = ""
    for ($i = 0; $i -lt $Message.Length; $i++) {
        $Decrypted += [char]($Message[$i] -bxor $global:encryption_key[$i % $global:encryption_key.Length])
    }
    return $Decrypted
}

<# ================================================================= #>
<# ======================== UDP TRANSMITTER ======================== #>
<# ================================================================= #>

function Start_UDP_Transmitter {
    try {
        # Credit for Transmitter Socket Code: Thomas Lee - tfl@psp.co.uk - http://www.pshscripts.blogspot.com 
        $global:dst_ip = Read-Host "Destination IP"
        $global:dst_port = [int](Read-Host "Destination Port")
        $global:dst_proto = "UDP"

        $Address = [system.net.IPAddress]::Parse($dst_ip)

        # Create IP Endpoint
        $End = New-Object System.Net.IPEndPoint $Address, $dst_port

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
        Write-Host "Successfully stopped the UDP transmitter" -ForegroundColor Blue
    }
    catch {
        Write-Host "ERROR: could not stop the UDP transmitter" -ForegroundColor Red
    }

    # note: that regardless of whether or not the close was successful, the transmitter is marked as inactive
    $global:transmitter = $false
    $global:dst_ip = ""
    $global:dst_port = 0
    $global:dst_proto = ""
    $global:prompt = ">"
}

function Transmit_UDP_Message {
    param (
        $Message
    )
    try {
        # Check if encryption is enabled
        if ($global:encryption_enabled) {
            $EncryptedMessage = Encrypt_XOR_Message -Message $Message
            $DecryptedMessage = $Message
            $Message = $EncryptedMessage
        }

        # Create encoded buffer
        $Enc = [System.Text.Encoding]::ASCII
        $Buffer = $Enc.GetBytes($Message)

        # Send the buffer via the established socket
        if ($Sock.Connected) {
            $Sock.Send($Buffer)
        } else {
            Write-Host "ERROR: Socket is not connected" -ForegroundColor Red
        }

        # Informational message for length
        $length = $Message.Length
        $date = Get-Date -UFormat "%m/%d/%Y %R UTC%Z"
        Write-Host "SENT ${length} Characters AT ${date}" -ForegroundColor Green

        # Log the transmission to the convo_file
        Add-Content -Path $convo_file -Value "----- SENT TO ${dst_ip}:${dst_port} ${dst_proto} AT ${date} -----"
        Add-Content -Path $convo_file -Value "$Message"
        if ($global:encryption_enabled) {
            Add-Content -Path $convo_file -Value "----- Decrypted Message Below -----"
            Add-Content -Path $convo_file -Value "$DecryptedMessage"
        }
    }
    catch {
        Write-Host "ERROR: could not send message" -ForegroundColor Red
    }
}

function Test_Connection {
    if ($transmitter) {
        try {
            # Test UDP connection
            $global:sock.Send([System.Text.Encoding]::ASCII.GetBytes("Test"))
            Write-Host "UDP connection to ${dst_ip}:${dst_port} ${dst_proto} is successful" -ForegroundColor Green
        }
        catch {
            Write-Host "ERROR: UDP connection to ${dst_ip}:${dst_port} ${dst_proto} is unsuccessful" -ForegroundColor Red
        }

        try {
            # Test ICMP ping
            $ping = New-Object System.Net.NetworkInformation.Ping
            $reply = $ping.Send($dst_ip)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                Write-Host "Ping to ${dst_ip} is successful" -ForegroundColor Green
            }
            else {
                Write-Host "ERROR: Ping to ${dst_ip} is unsuccessful" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "ERROR: Unable to ping ${dst_ip}" -ForegroundColor Red
        }
    } else {
        Write-Host "ERROR: Transmitter is not active" -ForegroundColor Red
    }
}

<# ================================================================= #>
<# ======================== TCP TRANSMITTER ======================== #>
<# ================================================================= #>

function Start_TCP_Transmitter {
    try {
        # Get destination IP and port from user
        $global:dst_ip = Read-Host -Prompt "Destination IP"
        $global:dst_port = [int](Read-Host -Prompt "Destination Port")
        $global:dst_proto = "(TCP)"

        $Address = [system.net.IPAddress]::Parse($dst_ip)

        # Create IP Endpoint
        $End = New-Object System.Net.IPEndPoint $Address, $dst_port

        # Create Socket
        $saddrf = [System.Net.Sockets.AddressFamily]::InterNetwork
        $Stype = [System.Net.Sockets.SocketType]::Stream
        $Ptype = [System.Net.Sockets.ProtocolType]::TCP
        $global:Sock = New-Object System.Net.Sockets.Socket $saddrf, $stype, $ptype

        # Connect to socket
        $global:sock.Connect($End)

        # Mark transmitter as working
        $global:transmitter = 1
        
        Write-Host "Successfully started the TCP transmitter" -ForegroundColor Blue
        $global:prompt = "${dst_ip}:${dst_port} ${dst_proto}>"
    }
    catch {
        Write-Host "ERROR: could not setup TCP transmitter" -ForegroundColor Red
        $global:transmitter = $false
    }
}

function Stop_TCP_Transmitter {
    try {
        $global:sock.Close()
        Write-Host "Successfully stopped the TCP transmitter" -ForegroundColor Blue
    }
    catch {
        Write-Host "ERROR: could not stop the TCP transmitter" -ForegroundColor Red
    }

    # note: that regardless of whether or not the close was successful, the transmitter is marked as inactive
    $global:transmitter = $false
    $global:dst_ip = ""
    $global:dst_port = 0
    $global:dst_proto = ""
    $global:prompt = ">"
}

function Transmit_TCP_Message {
    param (
        $Message
    )
    try {
        # Create encoded buffer
        $Enc = [System.Text.Encoding]::ASCII
        $Buffer = $Enc.GetBytes($Message)

        # Send the buffer via the established socket
        if ($Sock.Connected) {
            $Sock.Send($Buffer)
        } else {
            Write-Host "ERROR: Socket is not connected" -ForegroundColor Red
        }

        # Informational message for length
        $length = $Message.Length
        $date = Get-Date -UFormat "%m/%d/%Y %R UTC%Z"
        Write-Host "SENT ${length} Characters AT ${date}" -ForegroundColor Green

        # Log the transmission to the convo_file
        Add-Content -Path $convo_file -Value "----- SENT TO ${dst_ip}:${dst_port} ${dst_proto} AT ${date} -----"
        Add-Content -Path $convo_file -Value "$Message"
    }
    catch {
        Write-Host "ERROR: could not send message" -ForegroundColor Red
    }
}

<# ================================================================= #>
<# ========================= UDP RECEIVER ========================== #>
<# ================================================================= #>

# This is the code that opens in another window
$UDP_Receiver = {
    $port = [int](Read-Host "Select the UDP Listening Port")
    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient($port)
        $udpClient.Client.ReceiveTimeout = 1000
    } catch {
        Write-Host "ERROR: Unable to establish a listening port on ${port}" -ForegroundColor Red
        Exit
    }

    $remoteEndPoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)

    $date = Get-Date
    Clear-Host
    Write-Host "---------------------- UDP_LISTENER on port ${port} ----------------------" -ForegroundColor Blue
    Write-Host "Writing conversation to $convo_file" -ForegroundColor Blue
    Write-Host "Started Recording at ${date}" -ForegroundColor Blue
    # Add-Content -Path $convo_file -Value "----- Started Recording -----"

    try {
        while ($true) {
            try {
                $receiveBytes = $udpClient.Receive([ref]$remoteEndPoint)
                $receivedData = [Text.Encoding]::ASCII.GetString($receiveBytes)
                $senderIP = $remoteEndPoint.Address.ToString()
                $senderPort = $remoteEndPoint.Port

                $date = Get-Date
                Write-Host "----- RECEIVED FROM ${senderIP}:${senderPort} AT ${date} -----" -ForegroundColor Green
                Write-Host "$receivedData"

                # Add-Content -Path $convo_file -Value "----- RECEIVED FROM ${senderIP} AT ${date} -----"
                # Add-Content -Path $convo_file -Value "$receivedData"
            } catch {}
        }
    } finally {
        Write-Host "---------------------- Stopped Recording on port ${port} ----------------------" -ForegroundColor Blue
        # Add-Content -Path $convo_file -Value "----- Stopped Recording at ${date} on UDP port ${port} -----"
        $udpClient.Close()
    }
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
#UDP start - begins the udp transmitter
#UDP stop / #UDP_end - stops the udp transmitter
#UDP listen- opens a udp listener window
#TCP start - begins the tcp transmitter
#TCP stop / #TCP_end - stops the tcp transmitter
#info - gives info on the transmitter
#UDP test - tests the current UDP transmitter
#set file - designates a file to store the conversation
#clear file - clears the conversation file
#read file - opens a terminal that reads the conversation
#enable encryption - enables message encryption
#disable encryption - disables message encryption
#set key - sets the encryption key
#q / #quit - exits the program and closes the socket" -ForegroundColor Green
        }
        # setup the udp transmitter
        "#UDP start" { Start_UDP_Transmitter }
        # close the udp transmitter
        "#UDP end" { Stop_UDP_Transmitter }
        "#UDP stop" { Stop_UDP_Transmitter }
        # opens a udp listener window
        "#UDP listen" {
            Start-Process -FilePath powershell.exe -WorkingDirectory $pwd -ArgumentList "Set-Variable -Name `"convo_file`" -Value `"conversations.txt`"; $UDP_Receiver"
        }
        # setup the tcp transmitter
        "#TCP start" { Start_TCP_Transmitter }
        # close the tcp transmitter
        "#TCP end" { Stop_TCP_Transmitter }
        "#TCP stop" { Stop_TCP_Transmitter }
        # prints the transmission info
        "#info" {
            if ($transmitter) {
                Write-Host "Dest IP: ${global:dst_ip}" -ForegroundColor Green
                Write-Host "Dest Port: ${global:dst_port}" -ForegroundColor Green
                Write-Host "Protocol: ${global:dst_proto}" -ForegroundColor Green
            }
            else {
                Write-Host "Transmitter is not active" -ForegroundColor Green
            }
            Write-Host "Conversation File: ${convo_file}" -ForegroundColor Green
        }
        # tests the connection to the target
        "#UDP test" {
            Test_Connection
        }
        # setup the save file
        "#set file" {
            $global:convo_file = Read-Host "Enter the file name"
        }
        # clear the conversation file
        "#clear file" {
            Out-File -FilePath $convo_file -InputObject $null
        }
        # open file reader
        "#read file" {

        }
        # enable encryption
        "#enable encryption" {
            Enable_Encryption
        }
        # disable encryption
        "#disable encryption" {
            Disable_Encryption
        }
        # set encryption key
        "#set key" {
            Set_Encryption_Key
        }
        # quit program
        "#q" { Exit }
        "#quit" { Exit }
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
        Write-Host $global:prompt -NoNewline
        $UserInput = Read-Host

        # Runs commands starting with "#"
        if ($UserInput -imatch "^#") { 
            UserCommands($UserInput) 
        }

        # If the transmitter is setup, attempt to transmit the message
        elseif ($global:transmitter -and $global:dst_proto -eq "UDP") {
            Transmit_UDP_Message $UserInput
        }
        elseif ($global:transmitter -and $global:dst_proto -eq "TCP") {
            Transmit_TCP_Message $UserInput
        }

        # If the transmitter is not setup, give an error
        else {
            Write-Host "ERROR: no working transmitter" -ForegroundColor Red
            Write-Host "Try #help for a list of commands" -ForegroundColor Green
        }
    }
} finally {
    Write-Host "Goodbye!" -ForegroundColor Green
    if ($global:transmitter) {
        Stop_UDP_Transmitter
    }
}