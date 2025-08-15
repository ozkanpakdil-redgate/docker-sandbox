docker network create --driver bridge nfs_network
docker build --no-cache  -t nfs-server .
docker run -dit --privileged --name nfs-server --network nfs_network nfs-server