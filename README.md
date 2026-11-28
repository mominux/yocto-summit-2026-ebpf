This layer was prepared for my presentation at Yocto Project Summit 2026.
I extracted it from the `meta-lockdown` layer I presented at Open Source Summit
Europe 2026 and adapted it for this talk. I was too lazy to rename it, so it
kept the same name. ;)

## Clone Project:
git clone https://github.com/mominux/yocto-summit-2026-ebpf.git
cd yocto-summit-2026-ebpf

## Install requirements:
python3 -m venv ~/.venvs/yocto-kas                    
source ~/.venvs/yocto-kas/bin/activate
pip install -r requirements.txt
kas --version

## Optional: reuse existing downloads and sstate cache

To reuse your existing BitBake downloads and sstate cache, copy the example
overlay:

```sh
cp kas/local-cache.yml.example kas/local-cache.yml
```

Edit `kas/local-cache.yml` and set `DL_DIR` and `SSTATE_DIR` to the absolute
paths of your existing directories. Make sure they are writable. The file is
Git-ignored, and `env.sh` automatically includes it in `KAS_FILE` when sourced.
If you create or change the overlay after sourcing `env.sh`, source it again.

## Build resources

My build machine had limited resources, so `kas/lockdown.yml` limits
`BB_NUMBER_THREADS`, `PARALLEL_MAKE`, and `PARALLEL_MAKEINST` to 2. This
reduces parallelism and memory pressure; it is not a hard RAM limit. If your
machine has plenty of resources, adjust these settings or comment out the
three assignments in the `build-resources` section to use the default
parallelism.

## Create build environment:
source ./env.sh
kas --version
echo "$KAS_WORK_DIR"
echo "$KAS_FILE"

## Build image:
kas build "$KAS_FILE"

## Run OEQA test:
kas shell "$KAS_FILE" -c 'bitbake -c testimage lockdown-image'

## Run Qemu :
kas shell "$KAS_FILE" -c 'runqemu qemuarm64 ext4 slirp nographic'

