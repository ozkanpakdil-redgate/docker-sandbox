docker build --no-cache  -t postgresubuntu16 .
docker run -dit --name postgresubuntu16 -p 5432:5432 -p 22:22 postgresubuntu16
docker cp postgresubuntu16:/root/.ssh/id_rsa ./root.key
ssh -i root.key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost