# bootc-testing &nbsp; [![bluebuild build badge](https://github.com/nobodywatchin/bootc-testing/actions/workflows/build.yml/badge.svg)](https://github.com/nobodywatchin/bootc-testing/actions/workflows/build.yml)

These are some custom bootc-based images based around EL9 and EL10 distributions.

There are currently both CentOS and Almalinux images.

The GNOME Desktop is included with some extensions added as well.

A custom 'dnf4" module has been created to allow for easy installation of packages on the EL9 images.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/nobodywatchin/bootc-testing
```

# Building

Currently, the ISO file installs to the first hard drive it finds automatically.
I am not responsible if you format the wrong hard drive!

To Build the ISO file, run:

```bash
sudo podman pull ghcr.io/nobodywatchin/alma9-testing:latest && \
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest && \
sudo podman run \
  --rm \
  -it \
  --privileged \
  --pull=never \
  --network host \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type anaconda-iso \
  ghcr.io/nobodywatchin/alma9-testing:latest
```