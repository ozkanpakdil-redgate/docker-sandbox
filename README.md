# How to run postgresql in local
Run the commands below
```shell
cd postgres-ubuntu
docker build --no-cache  -t postgresubuntu .
docker run -dit --name postgresubuntu -p 5432:5432 -p 22:22 postgresubuntu
docker cp postgresubuntu:/root/.ssh/id_rsa ./root.key
ssh -i root.key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost
```

or you can run the [this](./postgres-ubuntu/setup.ps1) setup PS file which will prepare everything and connect with ssh.
