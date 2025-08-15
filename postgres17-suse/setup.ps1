docker build --no-cache -t postgressuse17 .
docker run -dit --privileged --name postgressuse17 --network nfs_network -p 5432:5432 -p 22:22 postgressuse17
docker cp postgressuse17:/root/.ssh/id_rsa ./root.key
ssh -i root.key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost