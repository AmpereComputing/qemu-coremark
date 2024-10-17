{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (system: {
      nixosConfigurations = nixpkgs.lib.nixosSystem {
        modules = [
          (
            { config, pkgs, ... }:
            {
              imports = [ "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix" ];

              environment.systemPackages = [
                pkgs.libaio
                pkgs.cmake
                pkgs.unzip
                pkgs.stdenv.cc
                pkgs.phoronix-test-suite
                (pkgs.writeShellScriptBin "run_pts" ''
                  num_iterations=''${1:-1}

                  for iter in $(seq 1 ''${num_iterations}); do
                    rm -f /tmp/coremark-results
                    ${nixpkgs.lib.getExe pkgs.phoronix-test-suite} debug-benchmark pts/coremark >> /tmp/coremark-results

                    score=$(cat /tmp/coremark-results | grep "Average: " | cut -d " " -f2 | cut -d"." -f1)
                    echo "Round $iter - CoreMark Score is: $score"
                  done
                '')
              ];

              users.users.ampere = {
                description = "Ampere Benchmarking";
                password = "ampere";
                createHome = true;
                isNormalUser = true;
                extraGroups = [ "wheel" ];
              };

              security = {
                sudo = {
                  enable = true;
                  wheelNeedsPassword = false;
                };
                polkit.enable = true;
              };

              services = {
                cloud-init.enable = true;
                getty = {
                  autologinUser = "ampere";
                  helpLine = ''
                    The "ampere" user has been automatically logged in.
                    You may run the benchmark via running "run_pts".
                  '';
                };
                openssh.enable = true;
              };

              nixpkgs = {
                hostPlatform.system = "aarch64-linux";
                buildPlatform = {
                  inherit system;
                };
              };

              virtualisation = {
                graphics = false;
                qemu = {
                  options = [ (if pkgs.stdenv.buildPlatform.isAarch64 then "--enable-kvm" else "-cpu neoverse-n1") ];
                  networkingOptions = [
                    "-net nic,netdev=user.1,model=virtio"
                    "-netdev user,id=user.1,\${QEMU_NET_OPTS:+,$QEMU_NET_OPTS}"
                  ];
                };
                useNixStoreImage = true;
                writableStore = true;
              };

              system.stateVersion = "24.11";
            }
          )
        ];
      };

      packages.default = self.nixosConfigurations.${system}.config.system.build.vm;

      devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = [
          self.packages.${system}.default
          (nixpkgs.legacyPackages.${system}.writeShellScriptBin "launch_qemu" ''
            if [ -f "qemu_pids.txt" ]; then
              ${./stop_qemu.sh}
            fi

            count=0
            portnum=2000
            qemu_pids=()

            touch $NIX_BUILD_TOP/core_spread.txt

            while read line; do
              nohup taskset -c $line \
                ${nixpkgs.lib.getExe self.packages.${system}.default} \
                -device virtio-net-pci,netdev=eth0 \
                -netdev user,id=eth0,hostfwd=tcp::$portnum-:22 \
                -chardev file,id=char0,path=/tmp/qemu-serial-$count.log,signal=off -serial chardev:char0 > /tmp/qemu$count.log 2>&1 &

              echo -n "."
              qemu_pids+=($!)
              count=$((count+1))
              portnum=$((portnum+1))
            done < $NIX_BUILD_TOP/core_spread.txt

            echo ""
            sleep 5

            echo "Checking if VMs successfully started."
            count=0

            for p in "''${qemu_pids[@]}"; do
              if ! kill -0 "$p" 2>/dev/null; then
                echo "QEMU VM $count failed to start. See /tmp/qemu$count.log for details."
                exit 2
              fi
              count=$((count+1))
            done

            echo "Waiting for VMs to finish booting and installing pts/coremark."
            count=0
            while read line; do
              if ! grep -q 'Cloud-init target.' "/tmp/qemu-serial-$count.log"; then
                echo "Waiting for VM $count (check /tmp/qemu-serial-$count.log for progress)"
                while ! grep -q 'Cloud-init target.' "/tmp/qemu-serial-$count.log"; do
                  sleep 2
                  echo -n "."
                done
                echo ""
              fi
              count=$((count+1))
            done < $NIX_BUILD_TOP/core_spread.txt

            echo "''${qemu_pids[@]}" > "qemu_pids.txt"
            echo "The QEMU VMs are ready."
          '')
        ];
      };
    });
}
