docker build --no-cache -t postgresredhat17 .
docker run -dit --privileged --name postgresredhat17 --network nfs_network -p 5432:5432 -p 22:22 postgresredhat17
docker cp postgresredhat17:/root/.ssh/id_rsa ./root.key
ssh -i root.key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost