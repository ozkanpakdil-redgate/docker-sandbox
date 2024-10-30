nerdctl build --no-cache  -t postgresubuntu17 .
nerdctl run -dt --name postgresubuntu17 -p 5432:5432 -p 22:22 postgresubuntu17
nerdctl cp postgresubuntu17:/root/.ssh/id_rsa ./root.key
ssh -i root.key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost