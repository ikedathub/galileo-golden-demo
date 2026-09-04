FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

# The base image ships a Yarn apt source whose signing key can no longer be
# verified, so `apt-get update` exits 100 and every feature install on top of
# this image fails. Drop the source, then install what the app needs here so
# no lifecycle script has to touch apt at all.
RUN rm -f /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends libmagic1 \
    && rm -rf /var/lib/apt/lists/*
