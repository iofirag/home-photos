i have clients
each client buy my device and power it on in their home.

### on device powered on:
    #### check for internet connection availability
    NO internet (WiFi + Ethernet down)
        → start hotspot

    Ethernet plugged in OR WiFi connected
        → stop hotspot immediately

    Internet available
        → start claim process

### claim process:
    user can claim and add the device to his account by a short time code.

### on claiming success:
    Server creates Cloudflare tunnel
    Server configures ingress + DNS
    Server generates package files
    server will generate dedicated client unique files.
    server compress all client files
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
    the device will supply all docker-compose.yaml services in their network



# remote access:
admin can use the client tunnel connection to access remotely to device terminal.
`ssh -o ProxyCommand="cloudflared access ssh --hostname %h" <device-os-user>@ssh-<client-id>.<my-domain.com>`


questions:
should i change something for better solution?
if no -
how to make each step in production level?
what is the minimal OS should i install on the device?


# How to run:
Install on a prepared Raspberry Pi from the internet:
`curl -fsSL https://raw.githubusercontent.com/iofirag/home-photos/main/scripts/install.sh | sudo bash`

The installer downloads `onboarding.sh`, installs it at `/usr/local/bin/home-photos-onboarding.sh`, and creates `home-photos-onboarding.service` so onboarding starts on boot.

For client delivery:
1. Run the install command while preparing the Raspberry Pi.
2. Shut down the Raspberry Pi.
3. Give the client an ext4-formatted pendrive.
4. The client inserts the pendrive and powers on the Raspberry Pi.
5. The onboarding service waits for the pendrive, mounts it, and saves all client app files/data under `<pendrive>/client-app`.

logs -> `sudo tail -f /var/log/home-photos-onboarding.log`
docker logs -> `sudo journalctl CONTAINER_NAME=immich-server -f`
navigate to `http://home-photos:8080,8081,2283`

# reset device
reset -> `sudo /usr/local/bin/home-photos-hard-reset.sh`









#### TODO:
V save docker logs to volatile journald instead of persistent Docker json logs
V download install from network
V store all app in 1 directory
V uploading images to usb or run from usb
V (using without ip) - http://home-photos:<port>
How to Protect ssh-d1.aghaiofir.win with Cloudflare Access

###### OLD ######
onboarding step:
will  it to his local network / wifi
validate internet is available
do OTP authentication with my server

on authentication success:
server will send the user short-lived one-time url for download the files (docker-compose.yaml, .env, other files needed)


1. Client authenticates with your server
2. Server creates Cloudflare tunnel
3. Server configures ingress + DNS
4. Server generates package files
5. Server creates a short-lived download token
6. Client downloads ZIP
7. Server marks token as used



this computer should connect to their home network
this computer will supply immich, immichframe services in their network

i want to have a secured admin access to this computers.
i want the ability to access remotely to this computers by ssh to their terminal
use free or open source tools
use docker compose solution for easy operation
my clients are non-technical clients

immich:
each client will have the ability to upload media to his immich server also when his not in home network
each client should not see the other clients computer (client isolation)

immichframe:
immich albums slide show service.

ssh vboxuser@10.0.0.144
debugging: `docker compose up --build -d`
`aghaiofir.win`