# openresty-modsecurity-docker
docker image for openresty with modsecurity

## Build

```bash
docker build -t openresty-modsec:latest .
```

## Run

```bash
docker run -it -p 80:80 -d openresty-modsec:latest
```

## Docker Hub

[openresty-modsecurity](https://hub.docker.com/r/alexlogy/openresty-modsecurity)
