i have clients
each client buy my computer and should run it in their home
this computer should have onboarding step

onboarding step:
user will connect it to his local network / wifi
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

TODO:
How to Protect ssh-d1.aghaiofir.win with Cloudflare Access

===========
How to run:
===========
cd server
py app.py <client-id>

# copy gen files from `server/packages/<client-id>` to `client` folder
cd client
docker compose up --build -d