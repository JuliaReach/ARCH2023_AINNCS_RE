#!/bin/bash

# define names
id="${1:-id}"  # `id` becomes the first argument if provided and "id" otherwise
build_name="juliareach-ainncs-$id"
container_name="juliareach-ainncs-container-$id"
folder_name="juliareach_ainncs"  # see Dockerfile

# build
docker build . -t $build_name --no-cache

# run
docker run --name $container_name $build_name julia startup.jl

# restart (if the container was stopped)
# docker start $container_name
# docker exec -it $container_name julia startup.jl

# copy results
docker cp $container_name:/$folder_name/results/ .

# clean up
rm -Rf $folder_name
docker rm --force $container_name
docker image rm --force $build_name
