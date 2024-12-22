# Define the port to listen on
$port = 5000

# Create a UDP client
$udpClient = New-Object System.Net.Sockets.UdpClient $port

# Set a timeout for receiving data (optional)
$udpClient.Client.ReceiveTimeout = 1000

while ($true) {
    # Receive a datagram
    $remoteEndPoint = New-Object System.Net.EndPoint ([System.Net.IPAddress]::Any, $port)
    $receiveBytes = $udpClient.Receive([Ref]$remoteEndPoint)

    # Convert the received byte array to a string
    $receivedData = [Text.Encoding]::ASCII.GetString($receiveBytes)

    # Print the received data to the console
    Write-Host "Received data: $receivedData"

    # Close the UDP client (optional)
    $udpClient.Close()
}