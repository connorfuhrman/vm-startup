# VM Startup

This holds a Nix flake which wraps starting multiple VMs that I use. 
The package creates scripts for each VM that set specific variables and working directories.

I heavily referenced [this gist](https://gist.github.com/citruz/9896cd6fb63288ac95f81716756cb9aa) when creating/configuring the VMs.

## Assumptions
- Each VM is stored in `${VM_ROOT_DIR}/${VM_NAME}`. 
- Each VM's disk is `${VM_NAME}-disk.qcow2`
- Each VM is for aarch64 running on an ARM machine. 

## Testing
This has been validated on Darwin Apple Sillicon.
YMMV on other systems (and in general).
