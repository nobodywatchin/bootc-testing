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
