{
  description = "Virtual Machines";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem ["aarch64-darwin"] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        makeColorLine = color: text: ''
          echo -e "\033[${color}m${text}\033[0m"
        '';

        ansiColors = {
          red = makeColorLine "0;31";
          green = makeColorLine "0;32";
          blue = makeColorLine "0;34";
          yellow = makeColorLine "0;33";
        };

        ansiColorsScript = pkgs.writeText "color-utils" ''
          red() {
            ${ansiColors.red "$@"}
          }
  
          green() {
            ${ansiColors.green "$@"}
          }

          blue() {
            ${ansiColors.blue "$@"}
          }

          yellow() {
            ${ansiColors.yellow "$@"}
          }
        '';

        # Create a convenience to run a qemu virtual machine
        runQemuVm = { ncpu ? 8, nmem ? 12288, sshPort, background ? true }: 
          pkgs.writeScriptBin "run-qemu-vm" ''
             #!${pkgs.bash}/bin/bash

             set -e

             source ${ansiColorsScript}

             # First, ensure VM_ROOT_DIR is set
             if [ -z "$VM_ROOT_DIR" ]; then
               red "Error: VM_ROOT_DIR environment variable must be set to the directory containing your VMs"
               echo "For example: VM_ROOT_DIR=$HOME/vms ./result/bin/run-qemu-vm"
               exit 1
             fi

             # Validate that the VM directory exists
             VM_DIR="$VM_ROOT_DIR/$VM_NAME"
             if [ ! -d "$VM_DIR" ]; then
               red "Error: VM directory not found: $VM_DIR"
               exit 1
             fi

             cd "$VM_DIR"

             DISK=$VM_NAME-disk.qcow2

             # Construct the qemu command
             QEMU_CMD="${pkgs.qemu}/bin/qemu-system-aarch64 \
               -accel hvf \
               -m ${toString nmem} \
               -smp ${toString ncpu} \
               -cpu host \
               -M virt,highmem=on  \
               -drive file=${pkgs.qemu}/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on \
               -drive file=ovmf_vars.fd,if=pflash,format=raw \
               -drive if=none,file=$DISK,format=qcow2,id=hd0 \
               -device virtio-blk-device,drive=hd0,serial="dummyserial" \
               -device virtio-net-device,netdev=net0 \
               -netdev user,id=net0,hostfwd=tcp::${toString sshPort}-:22 \
               -nographic"

             green "Staring qemu VM $VM_NAME with command:"
             echo $QEMU_CMD
             echo ""

             ${if background then
             ''
             # Run in background mode
             blue "Starting VM in background mode. Logs will be written to $VM_DIR/qemu.log"
             # Use setsid to create a new session, preventing the process from being killed when the terminal closes
             ${pkgs.util-linux}/bin/setsid sh -c "exec $QEMU_CMD >> $VM_DIR/qemu.log 2>&1 < /dev/null &"

             # Give the VM a moment to start
             sleep 2

             # Check if the process is running by looking for the qemu process
             if pgrep -fq "qemu-system-aarch64.*$DISK"; then
               green "VM started successfully in background"
             else
               yellow "Warning: VM may have failed to start. Check $VM_DIR/qemu.log for details:"
             fi
             '' else ''
             blue "Starting VM in foreground mode. You will enter the VM shortly..."
             sleep 1
             exec $QEMU_CMD
             ''}
          '';

        makeVmScript = vmName: vmArgs@{ sshPort, ... }:
          let
            script = runQemuVm (vmArgs // {
              inherit sshPort;
            });
          in 
            pkgs.symlinkJoin {
              name = "vm-${vmName}-startup";
              paths = [ script ];
              buildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/run-qemu-vm \
                  --set VM_NAME "${vmName}"
              '';
            };
      in
      {
        packages = {
          debian-fg = makeVmScript "debian" {
            sshPort = 2220;
            background = false;
          };

          debian = makeVmScript "debian" {
            sshPort = 2220;
          };

          gentoo-fg = makeVmScript "gentoo" {
            sshPort = 2221;
            background = false;
          };

          gentoo = makeVmScript "gentoo" {
            sshPort = 2221;
          };
          
        };

        apps = {
          debian = {
            type = "app";
            program = "${self.packages.${system}.debian}/bin/run-qemu-vm";
          };
          
          debian-fg = {
            type = "app";
            program = "${self.packages.${system}.debian-fg}/bin/run-qemu-vm";
          };

          gentoo = {
            type = "app";
            program = "${self.packages.${system}.gentoo}/bin/run-qemu-vm";
          };
          
          gentoo-fg = {
            type = "app";
            program = "${self.packages.${system}.gentoo-fg}/bin/run-qemu-vm";
          };
        };
        
      }
    );
}
