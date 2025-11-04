{ lib, fetchurl, buildLinux, ... } @ args:

buildLinux (args // rec {
  version = "6.17-rc1";
  modDirVersion = "6.17.0-rc1";

  src = fetchurl {
    url = "https://git.kernel.org/torvalds/t/linux-${version}.tar.gz";
    # You'll need to update this hash after the first build attempt fails
    # Run the build, copy the correct hash from the error message
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  kernelPatches = [];

  extraMeta.branch = "6.17";
})
