FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"
SRC_URI += "file://defconfig file://hwmon.cfg"
SRC_URI += " \
 file://0002-hwmon-adm1275-Add-device-tree-support.patch \
 file://0003-hwmon-adm1275-Support-sense-resistor-parameter-from-.patch \
 file://0004-arm-dts-add-adm1278-for-barreleye.patch \
 file://0005-Updated-SCU88-register-and-SCU90-init-values.patch \
 "
