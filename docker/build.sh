#!/bin/bash
VERSION="0.0.1"

docker buildx build --platform linux/amd64,linux/arm64 --builder=container \
  --tag ngen-deps:$VERSION --tag ngen-deps:latest --file Dockerfile.ngen-deps . \
&& docker buildx build --platform linux/amd64,linux/arm64 --builder=container\
  --tag t-route:$VERSION --tag t-route:latest --file Dockerfile.t-route . \
&& docker buildx build --platform linux/amd64,linux/arm64 --builder=container\
  --tag ngen:$VERSION --tag ngen:latest --file Dockerfile.ngen . \
&& docker buildx build --platform linux/amd64,linux/arm64 --builder=container\
   --tag ngiab:$VERSION --tag ngiab:latest .

# docker buildx build --platform linux/amd64,linux/arm64 \
#   --build-arg VERSION=$VERSION \
#   --tag ngen-deps:ngen-deps-$VERSION --tag ngen-deps:latest --file Dockerfile.ngen-deps . \
# && docker buildx build --platform linux/amd64,linux/arm64 \
#   --build-arg VERSION=$VERSION \
#   --tag t-route:t-route-$VERSION --tag t-route:latest --file Dockerfile.t-route .
# && docker buildx build --platform linux/amd64,linux/arm64 \
#   --build-arg VERSION=$VERSION \
#   --tag ngen:ngen-$VERSION --tag ngen:latest --file Dockerfile.ngen . \
# && docker buildx build --platform linux/amd64,linux/arm64 \
#   --build-arg VERSION=$VERSION \
#   --tag ngiab:$VERSION --tag ngiab:latest .