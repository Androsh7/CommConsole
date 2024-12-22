<#  
.SYNOPSIS 
    Sends a UDP datagram to a port 
.DESCRIPTION 
    This script used system.net.socckets to send a UDP 
    datagram to a particular port. Being UDP, there's 
    no way to determine if the UDP datagram actually 
    was received.  
    for this sample, a port was chosen (20000). 
.NOTES 
    File Name  : Send-UDPDatagram 
    Author     : Thomas Lee - tfl@psp.co.uk 
    Requires   : PowerShell V2 CTP3 
.LINK 
    http://www.pshscripts.blogspot.com 
.EXAMPLE 
#> 

### 
#  Start of Script 
## 

# Define port and target IP address 
# Random here! 
[int] $Port = 20000 
$IP = "10.10.10.10" 
$Address = [system.net.IPAddress]::Parse($IP) 

# Create IP Endpoint 
$End = New-Object System.Net.IPEndPoint $address, $port 

# Create Socket 
$Saddrf   = [System.Net.Sockets.AddressFamily]::InterNetwork 
$Stype    = [System.Net.Sockets.SocketType]::Dgram 
$Ptype    = [System.Net.Sockets.ProtocolType]::UDP 
$Sock     = New-Object System.Net.Sockets.Socket $saddrf, $stype, $ptype 
$Sock.TTL = 26 

# Connect to socket 
$sock.Connect($end) 

# Create encoded buffer 
$Enc     = [System.Text.Encoding]::ASCII 
$Message = "Jerry Garcia Rocks`n"*10 
$Buffer  = $Enc.GetBytes($Message) 

# Send the buffer 
$Sent = $Sock.Send($Buffer) 
"{0} characters sent to: {1} " -f $Sent,$IP 
"Message is:" 
$Message 
# End of Script 