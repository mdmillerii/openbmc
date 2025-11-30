Convenience layer for building OpenBMC on ASPEED AST2600 EVB
================

This layer allows you to build OpenBMC for AST2600 EVB in the Aspeed BSP layer
without having to manually configure bblayers.conf and local.conf.

The AST2600 is an ARM, service management SOC made by ASPEED. More information
about the AST2600 can be found
[here](http://aspeedtech.com/server_ast2600/).

## Building and Running OpenBMC Using QEMU-ASPEED (evb-ast2600)

**Note** - When working in environments where the build machine, host machine
and client machine are on different networks, accessing the OpenBMC WebUI
through standard QEMU networking becomes unreliable. In such cases, the
qemu-aspeed wrapper provides a stable, predictable network configuration that
solves port-forwarding issues and allows seamless access to WebUI.

1. Clone OpenBMC

   ```bash
   git clone https://github.com/openbmc/openbmc.git
   ```

2. Build the evb-ast2600 OpenBMC Image (note this will take 30 - 120 minutes
   depending on your hardware)

   ```bash
   . setup evb-ast2600
   bitbake obmc-phosphor-image
   ```
   The evb-ast2600 image is now located in`build/tmp/deploy/images/evb-ast2600/obmc-phosphor-image-evb-ast2600.static.mtd`
   relative to your current directory.

3. Clone and build QEMU from the official upstream.
   ASPEED SoCs (AST2500/AST2600) are commonly used in BMC (Baseboard Management
   Controller) environments. QEMU provides emulation for these SoCs via
   qemu-system-arm.

   ```bash
   git clone https://gitlab.com/qemu-project/qemu.git
   cd qemu
   chmod u+x qemu-aspeed.sh
   ./configure --target-list=arm-softmmu --enable-fdt --enable-slirp
   make -j"$(nproc)"
   cd build/
   ```

4. Create qemu-aspeed.sh Script
   This script simplifies running ASPEED emulation.

   Create a file named qemu-aspeed.sh:
   ```bash
   #!/bin/bash
   MACHINE="2600"
   WEBPORT="4443"
   SSHPORT="2223"
   IMGDIR="ast2600-default"

   ast2600() {

   ./qemu-system-arm \
   -M ast2600-evb \
   -m 1024 \
   -drive file=${IMGDIR},format=raw,if=mtd \
   -nographic \
   -net nic,macaddr=F8:63:3F:66:95:11 \
   -net nic -net user,hostfwd=:0.0.0.0:${WEBPORT}-:443,hostfwd=:0.0.0.0:${SSHPORT}-:22,hostname=qemu

   }

   while [[ $# -gt 0 ]]; do
   case $1 in
      -m|--machine)
         MACHINE="$2"
         shift # past argument
         shift # past value
         ;;
      -w|--webport)
         WEBPORT="$2"
         shift # past argument
         shift # past value
         ;;
      -s|--sshport)
         SSHPORT="$2"
         shift # past argument
         shift # past value
         ;;
      -i|--img)
         IMGDIR="$2"
         shift # past argument
         shift # past value
         ;;
   esac
   done

   if [[ "$MACHINE" == "2600" ]]; then

   if [[ "$MACHINE" == "2600" ]] && [[ -f "$IMGDIR" ]] ; then
      ast2600
   else
      printf "\nInvalid IMGDIR : ${IMGDIR}\n\n"
   fi

   else
   printf "\nInvalid MACHINE : ${MACHINE}\n\n"
   fi
   ```
   Make it executable:

   ```bash
   chmod +x qemu-aspeed.sh
   ```

4. Copy the AST2600 image generated from your Yocto build into the /qemu/build
directory

   ```bash
   cp ./tmp/deploy/images/evb-ast2600/obmc-phosphor-image-evb-ast2600.static.mtd ./
   ```

5. Start QEMU-ASPEED with the evb-ast2600 image

   ```bash
   ./qemu-aspeed.sh -i obmc-phosphor-image-evb-ast2600.static.mtd -m 2600 -w 1234
   ```
   Run QEMU using the image and forward the WebUI port (e.g., 1234).

6. Wait for your qemu-aspeed based BMC to boot

   Login using default root/0penBmc login (Note the 0 is a zero).

7. Check the system state

   You'll see a lot of services starting in the console, you can start running
   the obmcutil tool to check the state of the OpenBMC state services. When you
   see the following then you have successfully booted to "Ready" state.

   ```bash
   root@openbmc:~# obmcutil state
   CurrentBMCState     : xyz.openbmc_project.State.BMC.BMCState.Ready
   CurrentPowerState   : xyz.openbmc_project.State.Chassis.PowerState.Off
   CurrentHostState    : xyz.openbmc_project.State.Host.HostState.Off
   ```

   **Note** To exit (and kill) your QEMU-ASPEED session run: `ctrl+a x`

8. Use a browser and open

   ```bash
   https://build-server-ip:1234
   ```
   Login using the same credentials: root / 0penBmc
