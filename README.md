# VM Startup

This holds a Nix flake which wraps starting multiple VMs that I use. 
The package creates scripts for each VM that set specific variables and working directories.

## Assumptions
- Each VM is stored in `${VM_ROOT_DIR}/${VM_NAME}`. 
- Each VM's disk is `${VM_NAME}-disk.qcow2`
- Each VM is for aarch64 running on an ARM machine. 

## Testing
This has been validated on Darwin Apple Sillicon.
YMMV on other systems (and in general).
