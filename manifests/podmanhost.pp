# Install docker from https://get.docker.com/ubuntu
class sunet::podmanhost(
) {
  include sunet::packages::podman
  include stdlib

}
