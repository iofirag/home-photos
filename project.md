i have clients
each client buy my device and power it on in their home.

### on device powered on:
Check for internet connection availability:
By a success response from https://clients3.google.com/generate_204 

NO internet (WiFi + Ethernet down) 
    → start hotspot (with Captive portal)

Internet available 
    → stop hotspot immediately 
    → start claim process

#### check for internet connection availability
Check curl to google.com retrieve 200 OK

NO internet (WiFi + Ethernet down)
    → start hotspot

Internet available
    → stop hotspot immediately
    → start claim process

### claim process:
    user can claim and add the device to his account by a short time code.
    send unique data to server hello
    server will respond with short time code
    user type this code in his account

### on claiming success:
    Server creates Cloudflare tunnel
    Server configures ingress + DNS
    Server generates client package files
    server compress all client files to a .zip
    server upload zip file to public location.
    server will let client download the files
    server will ignore the downloaded files

### device understand it can start download the files:
    the device start download the compressed files
    open them - and run the install script

### install process:
    device will run the install script
    in the install script it should install dependencies like: docker / git
    make the docker compose file run on boot

### on install finish:
    device should run `docker compose up -d`
    the device will supply all docker-compose.yaml services in local network


# remote access:
admin can use the client tunnel connection to access remotely to device terminal.
`ssh -o ProxyCommand="cloudflared access ssh --hostname %h" <device-os-user>@ssh-<client-id>.<my-domain.com>`


questions:
should i change something for better solution?
if no -
how to make each step in production level?
what is the minimal OS should i install on the device?