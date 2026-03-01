{
  description = "Nix-based 9p filesystem for JSLinux (TinyEMU)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Always build for x86_64-linux (JSLinux target)
        targetSystem = "x86_64-linux";

        # Override glibc to disable x86 ISA level check
        # JSLinux/TinyEMU only emulates x86-64 baseline (no SSE3/SSSE3/SSE4/POPCNT)
        # Without this, glibc 2.33+ fails with "CPU ISA level is lower than required"
        pkgs = import nixpkgs {
          system = targetSystem;
          overlays = [
            (final: prev: {
              glibc = prev.glibc.overrideAttrs (old: {
                configureFlags = (old.configureFlags or []) ++ [
                  "libc_cv_include_x86_isa_level=no"
                ];
              });
            })
          ];
        };

        # Packages available in the 9p filesystem
        nixEnv = pkgs.buildEnv {
          name = "nix-9p-env";
          paths = with pkgs; [ bash coreutils gcc gnumake ];
          pathsToLink = [ "/bin" "/lib" "/include" "/share" ];
        };

        # Closure info for copying the nix store
        closureInfo = pkgs.closureInfo { rootPaths = [ nixEnv ]; };

        # Complete rootfs with nix store closure
        rootfs = pkgs.runCommand "nix-9p-rootfs" {
          __structuredAttrs = true;
          exportReferencesGraph.closure = [ nixEnv ];
        } ''
          mkdir -p $out

          # Copy the full nix store closure
          mkdir -p $out/nix/store
          while IFS= read -r path; do
            if [ -e "$path" ]; then
              cp -a "$path" "$out/nix/store/"
            fi
          done < ${closureInfo}/store-paths

          # Copy buildEnv contents as root dirs (resolved symlinks)
          cp -aL ${nixEnv}/* $out/

          # Symlink for easy access
          ln -sf ${nixEnv} $out/nix/env

          # FHS directories
          mkdir -p $out/sbin $out/tmp $out/proc $out/sys $out/dev
          mkdir -p $out/etc $out/home $out/var $out/run $out/usr/local/bin

          # Init
          cat > $out/sbin/init << 'INITEOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev 2>/dev/null || true
exec </dev/hvc0 >/dev/hvc0 2>&1
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run
hostname nix-9p
export HOME=/root
export TERM=xterm-256color
export PATH="/bin:/usr/local/bin"
stty sane rows 24 cols 80 2>/dev/null
cat /etc/motd
while true; do
    /bin/bash -l
done
INITEOF
          chmod +x $out/sbin/init

          cat > $out/etc/motd << 'EOF'

Nix 9p filesystem for JSLinux
Packages: bash, coreutils, gcc, make

EOF
        '';

      in {
        packages = {
          default = rootfs;
          env = nixEnv;
        };
      }
    );
}
