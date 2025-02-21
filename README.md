## To build dev
```bash
./build_dev.sh
# or
docker build -t ngiab_dev -f docker/Dockerfile docker/ --target dev
```
## To build prod (the same format as the public NGIAB)
```bash
./build_prod.sh
# or
docker build -t ngiab_prod -f docker/Dockerfile docker/
```

## Explanation of the command

`docker build` - runs the builder  
`-t ngiab_dev` - this is the tag / image name. you can give it a version like `-t ngiab_dev:v0.0.1` if you want. `-t ngiab_dev` == `-t ngiab_dev:latest`  
`-f docker/Dockerfile` - the dockerfile that we want to build  
`docker/` - The build context, aka what files should the docker builder have access to. This doesn't automatically put them in the image, but it lets you COPY them into the image in the dockerfile  
`--target` - which docker stage to build. `FROM restructure_files AS dev` is the dev stage that keeps all the build files. `FROM rockylinux:9.1 AS final` is the default because it is the last stage in the dockerfile.  


# .guide.sh has been modified to let you run local dev, local prod, or the public NGIAB

The `ENTRYPOINT` in the dockerfile is what command will be run when launch the image, you can override it on the commandline with `--entrypoint /bin/bash`
 or just remove it if needed.

# Development inside the container
The easiest way to do this is probably to use the docker extension for VSCode or [dev containers](https://code.visualstudio.com/docs/devcontainers/containers). 

# Changing ngen/troute versions
You can either update the urls in the docker image git clone commands, or put your code inside the dockerfolder then copy it onto the image. 
`COPY your_model /ngen/ngen_src/external/`

# Mounting your data to the image
Guide.sh has examples of this and VSCode can manage this for you, 
```bash
docker run --rm -it -v "$HOST_DATA_PATH:/ngen/ngen/data" "$IMAGE_NAME"
```
`-v` does the mounting of local_folder:folder/in/image  
`--rm` kills the container after it is done running (DO NOT DO THIS IF YOU WANT TO KEEP IT RUNNING LIKE A VM)  
`-it` makes it interactive (like ssh onto a remote machine instead of running like an executable)  