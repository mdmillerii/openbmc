SUMMARY = "Phosphor OpenBMC OEM Commands for OpenPOWER systems"
DESCRIPTION = "Phosphor OpenBMC IPMI OEM commands for OpenPOWER based systems"
HOMEPAGE = "https://github.com/openbmc/openpower-host-ipmi-oem"
PR = "r1"

RRECOMMENDS_${PN} = "virtual/obmc-phosphor-host-ipmi-hw"

inherit obmc-phosphor-license

DEPENDS += "systemd    \
		 	host-ipmid \
		 	"
TARGET_CFLAGS += "-fpic"


RDEPENDS_${PN} += "libsystemd"



#SRC_URI += "git://github.com/openbmc/openpower-host-ipmi-oem"
SRC_URI += "git://github.com/anoo1/openpower-host-ipmi-oem;protocol=https;branch=flash"

SRCREV = "187bfced3d86fae7c93e3772fa7fa028d02e2c18"

FILES_${PN} += "${libdir}/host-ipmid/*.so"
FILES_${PN}-dbg += "${libdir}/host-ipmid/.debug"

S = "${WORKDIR}/git"

do_install() {  
        install -m 0755 -d ${D}${libdir}/host-ipmid
        install -m 0755 ${S}/*.so ${D}${libdir}/host-ipmid/
}
