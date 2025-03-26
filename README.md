# bootc-testing &nbsp; [![bluebuild build badge](https://github.com/nobodywatchin/bootc-testing/actions/workflows/build.yml/badge.svg)](https://github.com/nobodywatchin/bootc-testing/actions/workflows/build.yml)

These are some custom bootc-based images based around EL9 and EL10 distributions.

There are currently both CentOS and Almalinux images.

The GNOME Desktop is included with some extensions added as well.

These images are built strictly for testing -- they are NOT production-ready, use at your own risk!

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/nobodywatchin/bootc-testing
```

The [Red Hat](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems/deploying-the-rhel-bootc-images_using-image-mode-for-rhel-to-build-deploy-and-manage-operating-systems#building-and-launching-configured-images_deploying-the-rhel-bootc-images) and [OSBuild](https://osbuild.org/docs/bootc/) documentation on building bootc images is quite in-depth if you want to tinker. 

In the meantime, here are some simple commands to get up and running:

# Building as a VM

```bash
sudo podman pull ghcr.io/nobodywatchin/alma10-testing:latest && \
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest && \
sudo podman run \
  --rm \
  -it \
  --privileged \
  --pull=never \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  ghcr.io/nobodywatchin/alma10-testing:latest
```

# Building ISO File

When you boot this ISO, it will automatically install the operating system to the first hard drive it detects — without asking for confirmation.

Use with caution! I am not responsible if the installer formats the wrong hard drive. Double-check before proceeding!

To Build the ISO file, run:

```bash
sudo podman pull ghcr.io/nobodywatchin/alma10-testing:latest && \
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest && \
sudo podman run \
  --rm \
  -it \
  --privileged \
  --pull=never \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso \
  ghcr.io/nobodywatchin/alma10-testing:latest
```