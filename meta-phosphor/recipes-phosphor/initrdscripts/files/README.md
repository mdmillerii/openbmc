# Phosphor initfs
The obmc-phosphor-initfs package contains a collection of scripts that combine to maintain a filesystem using the default static images in flash.  When ombined with supporting utilities, they implement the [Systemd Init Interface]() using images stored in mapped memory technology devices (MTD) such as nor flash attached over a SPI bus and provide support to replace the images.

### Usage
`init`

`shutdown [_verb_ [ _systemd-options_ ]]`

  `_verb_` can be `shutdown`, `reboot`, `poweroff`, or `kexec`.   
  All are invoked with `-f` and `kexec` is also invoked with `-e`.

`update [_options_]`

### Features
#### Filesystem content delivered in Read-only images
- Delivered as an integrated unit
  - Take a known amount of space
    - Image size verified before delivery
  - Compressed during image creation
    - Reduces valuable space in flash
  - Components tested together
- Local modifications written into one filesystem
  - Can be cleaned and recreated for maintence
  - Stored in flash optimized filesystem
    - Understands erase blocks and interrupted writes
    - Shares overhead for erase blocks and logging
  - Can be filtered to known file paths
    - As recovery method when file system full
    - Upon code update or entry into development sandbox
      - Prevents unintentional overlay base image including point in time
  - Supports peristent writes in multple directories
    - `etc` requires some content to be overridden
    - `var` requires write access but no base content
    - `/home` desirable when login allowed
  -  Currently overlays full filesystem
    - Provides easy development environment to replace any file that fits in rwfs or RAM
    - Future plans to limit to required directories
#### Configurable and Extensible
- Configuration from sources available at OS, bootloader prompt, or image creation
  - See security considerations for methods to limit options
- Images stored in labeled MTD partitions
  - The label reflects their content: `rwfs`, `rofs`, `u-boot-env`
  - Image name matches MTD label
  - Additional partitions can be created and update images supplied
  - Full device labels are supported and contained partitions are scanned for delaying mounts
- Support to
  - apply remaining images at shutdown
  - prune or erase writable filesystem
  - download or inject rofs
  - inject additional updates supporting automated recovery
  - copy content into RAM allowing image application during runtime
  - perfor manual intervention and debug via shell on console device

##### Runtime configuration selecting additional or alterative `init`
- Selected by long option names to avoid conflicts
- Controlled by initrd content for deployment conotrol
  - Signed initrd or initramfs images allows owner control
  - Options can be built initrd image
    - Providing a set of always selected options
    - Optionally ignoring other sources below
- Can be read from kernel command line
  - typically `bootargs` variable at execution of `boot` command
- Can be read from Das U-Boot compatiable environment
  - Contained in two variables
    - Avoids undesired configuration from other macros
    - Allows one to always be cleared during os boot
  - Requires `setenv` then `saveenv` at bootloader
  - Alternatively can be set via `fw_setenv` from operating system
- Supports tweaks to execution and storage
  - Erase writable filesystem
    - optionally preserving selected content
  - Invoke a shell on detected error or demand
  - One or both layers of overlay copied into RAM supporting
    - Code update during system runtime (as flash is not mounted)
    - Support developer test and debug
      - Allow replacment of any content for one boot
      - Content obtained from initrd, MTD, or network
      - Initial overlay can be primed from writable overlay
      - Selected iles can be written back to writable overlay
#### systemd
- Implments the [Systemd Initrd Interface]()
  - `init` locates and mounts the filesystem stack
  - `shutdown` is copied into `/run/initramfs` by `init` and 
    - Unmounts overlay allowing `rwfs` to unmount
    - Calls `update` after filesystems are unmounted
      - with watchdogd pinging watchdog device
- Both `init` and `shutdown` integrate with `update` for code update and development environment support
- All three share knowlege of expected filesystem mountpoinits and update image storage locations
#### Provides an enviornment and method to update content
- Images staged in `/run/initramfs` (a `tmpfs`)
- Images written to MTD partition with `flash_copy`
- Flash written when images are unmounted (eg at system reboot or shutdown)
- Special hooks allow reboot into online volatile environment
  - Supports image update while main operation continues
  - Provides temporary environemnt to download, test, and debug
- Can flash image
#### Troubleshooting and Recovery environment
- Init configuration tweaks were developed incrementally during the debug of
  - the `init` script
  - the code `update` script
- Debug shell
  - Can Replace default of inducing kernel panic expecting watchdog or panic timer to cause reboot
  - Allows interactive troubleshooting and recovery
  - Allows multiple transitions between code update and full filesystem
  - Note job control is not available on `/dev/console`
    - execute `getty -l /bin/sh _console-device_` to obtain job control
    - to find console device try `cons=$(tr ' ' '\n' < /sys/class/tty/console/active | tail -n 1)`
- Will call shell repeatedly until
  - The shell exists cleanly (`exit 0`)
  - The file `/takeover` is found, in which case
    - The shell will be invoked via `exec(2)`
    - Allowing edit of `init` script
      - to be restarted via `exec init`

##### Security Considerations
- By default `init` exits on error inducing  kernel panic
  - It's expected the kernel `panic=` or watchdog will result in a new attempt
- Initrd signing can be combined with secure boot to prevent options parsing 
  - images or signed injections and selection mechanisms would need to be created to support
    - factory reset
    - clean rwfs filesystem
    - runtime, online code update
      - Content copied into memory
- File injection can can be used
  - Files injected into initrd can select some options
  - Files injected into initrd can skip other sources
- All network download or indivual url schemes can be disabled by patching configuration variable settings in the init script
##### Security Considerations
- Scripts can be modified before execution as desribed in [Developer notes](README.md#Deceloper)
  - `shutdown` and `update` execute from `/run/initramfs`
    - they can be edited altering their content before invocation
  - `init` can exit to a shell and then be replaced or restarted
  - `init` can be invoked after `shutdown` commpletes instead of calling the `_verb_`
- Features can be selected at bootloader via
  - Can be configured by injecting files into initramfs
  - Can be configured to automatically download read only image from network
  - Files injected into the initrd
    - Concatinating cpio.gz use for iniramfs
    - Building an image with additional file(s)
  - The kernel command line
    - In `Das U-Boot` when `boot` command is issued the contents of `bootargs` are passed to the payload
  - From named bootloader environment variables
    - `openbmcinit` for persistent options
    - `openbmconce` for options expected to be cleared each boot
      - the variable is expected to be cleared by a systemd unit

##### patchable or editable configuration
`# Set to y for yes, anything else for no.`
option and default | description
-|-
`force_rwfst_jffs2=y` | If rwfs is recognized as containing a block based filesystem save files and erase the partition to select replacement jffs filesystem
`flash_images_before_init=n` | apply injected images before mounting filesystem
`consider_download_files=y` | look for option to download image-rofs from network
`consider_download_tftp=y` | recognise `tftp:` scheme
`consider_download_http=y` | recognise `http:` scheme
`consider_download_ftp=y` | recognise `ftp:` scheme

#### `init` options
option | description
-|-
`enable-initrd-debug-sh` | invoke debug shell loop instead of exiting expecting a kernel panic
`debug-init-sh` | invoke shell after establishing `shutdown` evironment
`clean-rwfs-filesystem` | remove paths not designated for preservation across code updates from rwfs filesystem
`factory-reset` | erase rwfs filesystem without preserving any writable content
`overlay-filesystem-in-ram` | store overlay in ram (starting with no content)
`copy-files-to-ram` | copy files to be preserved into ram overlay
`copy-base-filesystem-to-ram` | copy content of rofs into ram (allowing partition to be written during runtime)

# init operation
- Changes current directory to `/`
- Establishes special filesystem mounts supporting utilities
  - `/dev`
  - `/proc`
  - `/sys`
- Creates `shutdown` execution environment under `/run/initramfs`
  - Mount a `tmpfs` at `/run` and make directory as needed
  - Recursively copy package and supporting utility content into directory
- Assemble options into `/run/initramfs/init-options` by copying from `/init-options` or combining `/init-options-base` with the `openbmcinit` and `openbmconce` variables from `u-boot-env` partition and the kernel command line content in `/proc/cmdline` into `/run/initramfs/init-options`
- Locates and prints MTD partitions labeled `rofs` and `rwfs` by number
- Invoke Debug Shell if selected by `debug-init-sh`
- Downloads `/run/image-rofs` if selected by `openbmc-init-download-files`
  - Presumes use of the [nfsroot kernel command line]() option `ip=`
    - Copies `/proc/net/pnp` to `/run/systemd/resolve/resolv.conf` and establishes symlink from `/etc/resolv.conf`
  - Obtains the download url from first location found among
    - `/init-download-url`
    - `/run/initramfs/init-download-url`
    - `openbmcinitdownloadurl` bootloader environment variable
  - Chooses command from the URL
    | scheme | command |
    |-|-|
    | `http` | `wget` |
    | `ftp` | `wget` |
    | `tftp` | `tftp -g` |
- Moves any injected code update images
  - from `/image-*` to `/run/image-` for immediate use
  - from `/image-*` to `/run/initramfs/image-*` for immediate update (selected by script config variable ``)
- Considers `rwfs` image maintence
  - If selected by `clean-rwfs-filesystem`
  - If the content of `rwfs` recognised as another filesystem but configuration forces `jffs` (force migration from inferior interm choices)
  - If selected by `factory-reset`
    - also suppresses preservation of any content via `--no-save-files`
  - By creating empty `/run/initramfs/image-rwfs` update
- Invokes `update` to apply images preserving content
  - Calls `flasherase` on `rwfs` if triggered by empty update
- Copies files in preserve list into ram if selected by `copy-files-files-to-ram`
- Copys `rofs` partition into ram (unless image downloaded) for loopback mount
- Mounts `rofs` on `/run/ro`
- If it exists, runs `fsck._rwfst_` from `rofs` using a `chroot` environment
- Mounts `rwfs` on `/run/rw` (except when runninig with overlay in ram)
- Establishs directories for work (empty) and overlay content in rw mount space
- Fast forwards date to the latest of
  - the current kernel time (supporting working RTC)
  - `/etc/os-release` from mounted `rofs` image
  - `/var/lib/systemd/random-seed` from possibly mounted `rwfs` filesystem
- Creates overlay combining `rwfs` and `rofs` and mounts on `/root`
- Confirms non-empty executable exists at `/sbin/init`
- Moves basic filesystems onto `/root`
- Invokes `switchroot` to
  - Unlink content from initramfs
  - Perform magic needed for `pivot_root`
  - Invoke `/sbin/init`

- mounts including
    - `/usr` content
    - `/etc` with writable overlay over the base image
    - `/run/` including
      - `/run/initramfs` execution environment
        - `/run/initramfs/shutdown`
    - Several other filesystems
      - `/var` mounted writable space over empty base directory
      - `/sys`
      - `/proc`
      - `/dev`
##  Possible Future Enhancements
- Restrict overlay directories to those required
  - Match writability of other [filesystem layouts]()
    - Only overlay `etc` from filesystem
    - Bind mount `/var` and `/home`
  - Provide option for full development overlay in ram
- Split paths in filesystem to be preserved
  - Allow selective factory reset by removing inidividual files
  - Adopt inclusive naming standards
- Allow support other image downloads
- Parse config variables from file
  - Disable / Enable configuration
  - Name of image files
  - Storage beyond MTD partitions
  - Share between `init` `update` and `shutdown`
- Option to automatically apply update images during boot
## Reference
- [filesystem layouts](https://github.com/openbmc/docs/blob/master/architecture/code-update/flash-layout.md#writable-filesystem-options)
- [Systemd Initrd Interface](https://systemd.io/INITRD_INTERFACE/)
- [nfsroot kernel command line](https://docs.kernel.org/admin-guide/nfs/nfsroot.html#kernel-command-line)
