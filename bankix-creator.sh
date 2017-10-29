#!/bin/bash

RELEASE="16.10"
LSB_RELEASE=$(lsb_release -sc)
KERNEL_RELEASE=$(uname -r)
KERNEL_VERSION=${KERNEL_RELEASE%%-*}

echo
echo "Bauanleitung"
echo "============"
echo
echo "1. Das vorliegende Skript bitte in (L)Ubuntu ${RELEASE} 32 Bit ausfuehren."
echo "2. Nach Durchlauf des Skriptes steht ein ISO-Image (live.iso) bereit, dass auf einen USB-Stick gebracht werden muss."
echo "  a) Den USB-Stick (min. 2 GB, besser 4 GB) entsprechend (eine Partition, FAT32) formatieren (bspw. mithilfe der Anwendung 'Laufwerke')."
echo "  b) Das Bootflag des Sticks setzen (bspw. mithilfe der Anwendung 'GParted')."
echo "  c) Das ISO-Image (live.iso) mithilfe der Anwendung 'UNetbootin' auf den Stick bringen (PS: Der Startmedienersteller ermoeglicht keine volle Funktionalitaet des bankix-Systems)."
echo
read -r -p "Das habe ich verstanden. [j/N] " questionResponse
echo 

if [[ $questionResponse != [jJ] ]]
then
 exit
fi

set -o xtrace

#### Kernel bauen #### BEGIN ####

# Kernel-Verzeichnis anlegen, benoetigte Pakete einspielen, Kernel-Quellcode herunterladen
mkdir kernel
cd kernel

# Quelltext-Paketquelle hinzufügen/aktivieren
add-apt-repository -s "deb http://de.archive.ubuntu.com/ubuntu/ ${LSB_RELEASE}-updates main"
apt-get update

apt-get -y install fakeroot
apt-get -y build-dep linux-image-${KERNEL_RELEASE}
apt-get source linux-image-${KERNEL_RELEASE}

### Patch erstellen und anwenden

cat > opticalDrivesOnly.patch << EOF
--- linux-${KERNEL_VERSION}/include/linux/libata.h
+++ linux-${KERNEL_VERSION}/include/linux/libata.h
@@ -1531,7 +1531,7 @@
 
 static inline unsigned int ata_dev_enabled(const struct ata_device *dev)
 {
- return ata_class_enabled(dev->class);
+ return dev->class == ATA_DEV_ATAPI; /* optical drives only (mid) */
 }
 
 static inline unsigned int ata_dev_disabled(const struct ata_device *dev)
EOF

patch -p0 --verbose --ignore-whitespace < opticalDrivesOnly.patch

# Kernel bauen
cd linux-${KERNEL_VERSION}

fakeroot debian/rules clean
skipabi=true skipmodule=true fakeroot debian/rules binary-indep
skipabi=true skipmodule=true fakeroot debian/rules binary-perarch
skipabi=true skipmodule=true fakeroot debian/rules binary-generic

cd ../../

#### Kernel bauen #### END ######


#### Return-Values der Bash-Kommandos auswerten #### BEGIN #####

function CHECK()
{
 #if [ ${PIPESTATUS[0]} -ne 0 ]
 if [ $? -eq 0 ]
 then
 echo $(tput bold)$(tput setaf 2)[PASS]$(tput sgr0)
 else
 echo $(tput bold)$(tput setaf 1)[FAIL]$(tput sgr0)
 fi
}
export PS4='$(CHECK)\n\n$(tput bold)$(tput setaf 7)$(tput setab 4)+ (${BASH_SOURCE}:${LINENO}):$(tput sgr0) '

#### Return-Values der Bash-Kommandos auswerten #### END #######


#### System bauen #### BEGIN ####

apt-get -y install build-essential debootstrap squashfs-tools genisoimage syslinux-common syslinux-utils
wget -c -N -P source http://cdimage.ubuntu.com/lubuntu/releases/${RELEASE}/release/lubuntu-${RELEASE}-desktop-i386.iso

mount -o loop source/lubuntu-${RELEASE}-desktop-i386.iso /mnt/
mkdir iso
cp -r /mnt/.disk/ /mnt/boot/ iso/
mkdir iso/casper

# Bereits gebautes Live-System des verwendeteten ISOs entpacken
unsquashfs -d squashfs /mnt/casper/filesystem.squashfs

# Ressourcen des Build-Systems in Live-System hineinmappen
mount --bind /dev squashfs/dev
mount -t devpts devpts squashfs/dev/pts
mount -t proc proc squashfs/proc
mount -t sysfs sysfs squashfs/sys

# DNS + Paketquellen des Build-Systems nutzen, vorher Ressourcen des Live-Systems sichern
chroot squashfs/ cp -dp /etc/resolv.conf /etc/resolv.conf.original
chroot squashfs/ cp -dp /etc/apt/sources.list /etc/apt/sources.list.original
cp /etc/resolv.conf squashfs/etc/
cp /etc/apt/sources.list squashfs/etc/apt/

# System schlank machen
chroot squashfs/ apt-get -y purge pidgin* abiword* transmission* gnumeric* xfburn* mtpaint simple-scan* sylpheed* audacious* guvcview fonts-noto-cjk ubiquity* mplayer language-pack* lvm2 gparted apport whoopsie blue* btrfs* cryptsetup evolution* gdebi* genisoimage lubuntu-software-center
chroot squashfs/ apt-get -y purge linux-image-* linux-headers-*
chroot squashfs/ apt-get -y autoremove --purge

# alle Updates einspielen
chroot squashfs/ apt-get update
chroot squashfs/ apt-get -y dist-upgrade

# Zusaetzliche Pakete einspielen
chroot squashfs/ apt-get -y install tzdata language-pack-de firefox-locale-de squashfs-tools cups network-manager-openconnect-gnome wswiss wngerman language-pack-gnome-de wogerman

# Zeitzone setzen
echo "Europe/Zurich" | tee squashfs/etc/timezone
rm squashfs/etc/localtime
chroot squashfs/ ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
chroot squashfs/ dpkg-reconfigure --frontend noninteractive tzdata

# Modifizierten Kernel einspielen
cp kernel/linux-headers*.deb kernel/linux-image*.deb squashfs/
chroot squashfs/ ls | chroot squashfs/ grep .deb | chroot squashfs/ tr '\n' ' ' | chroot squashfs/ xargs dpkg -i
chroot squashfs/ apt-get -f -y install
rm squashfs/*.deb

# APT + Software-Center aufrauemen
chroot squashfs/ apt-get -y check
chroot squashfs/ apt-get -y autoremove --purge
chroot squashfs/ apt-get -y clean
rm squashfs/var/cache/lsc_packages.db

# Firefox-Profil im Ordner source/skel erzeugen
mkdir -p source/skel/.mozilla/firefox/ctbankix.default/extensions
wget -c -N -O source/skel/.mozilla/firefox/ctbankix.default/extensions/{73a6fe31-595d-460b-a920-fcc0f8843232}.xpi https://addons.mozilla.org/firefox/downloads/latest/noscript/addon-722-latest.xpi

cat > source/skel/.mozilla/firefox/profiles.ini << EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=default
IsRelative=1
Path=ctbankix.default
EOF

cat > source/skel/.mozilla/firefox/ctbankix.default/prefs.js << EOF
# Mozilla User Preferences

/* Do not edit this file.
 *
 * If you make changes to this file while the application is running,
 * the changes will be overwritten when the application exits.
 *
 * To make a manual change to preferences, you can visit the URL about:config
 */

user_pref("browser.bookmarks.restore_default_bookmarks", false);
user_pref("browser.cache.disk.capacity", 0);
user_pref("browser.cache.disk.filesystem_reported", 1);
user_pref("browser.cache.disk.smart_size.enabled", false);
user_pref("browser.cache.disk.smart_size.first_run", false);
user_pref("browser.cache.disk.smart_size.use_old_max", false);
user_pref("browser.cache.frecency_experiment", 3);
user_pref("browser.download.importedFromSqlite", true);
user_pref("browser.download.useDownloadDir", false);
user_pref("browser.laterrun.enabled", true);
user_pref("browser.migrated-sync-button", true);
user_pref("browser.migration.version", 40);
user_pref("browser.newtabpage.enhanced", true);
user_pref("browser.newtabpage.storageVersion", 1);
user_pref("browser.pagethumbnails.storage_version", 3);
user_pref("browser.places.smartBookmarksVersion", 8);
user_pref("browser.preferences.advanced.selectedTabIndex", 0);
user_pref("browser.privatebrowsing.autostart", true);
user_pref("browser.reader.detectedFirstArticle", true);
user_pref("browser.search.countryCode", "CH");
user_pref("browser.search.region", "CH");
user_pref("browser.search.update", false);
user_pref("browser.search.useDBForOrder", true);
user_pref("browser.slowStartup.averageTime", 1705);
user_pref("browser.slowStartup.samples", 2);
user_pref("browser.startup.homepage", "https://ebanking.raiffeisen.ch");
user_pref("browser.tabs.remote.autostart.2", true);
user_pref("browser.uiCustomization.state", "{\"placements\":{\"PanelUI-contents\":[\"edit-controls\",\"zoom-controls\",\"new-window-button\",\"privatebrowsing-button\",\"save-page-button\",\"print-button\",\"history-panelmenu\",\"fullscreen-button\",\"find-button\",\"preferences-button\",\"add-ons-button\",\"developer-button\",\"sync-button\"],\"addon-bar\":[\"addonbar-closebutton\",\"status-bar\"],\"PersonalToolbar\":[\"personal-bookmarks\"],\"nav-bar\":[\"urlbar-container\",\"search-container\",\"bookmarks-menu-button\",\"downloads-button\",\"home-button\",\"pocket-button\",\"noscript-tbb\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"toolbar-menubar\":[\"menubar-items\"]},\"seen\":[\"pocket-button\",\"developer-button\"],\"dirtyAreaCache\":[\"PersonalToolbar\",\"nav-bar\",\"TabsToolbar\",\"toolbar-menubar\",\"PanelUI-contents\",\"addon-bar\"],\"currentVersion\":6,\"newElementCount\":0}");
user_pref("capability.policy.maonoscript.sites", "[System+Principal] about: about:addons about:blank about:blocked about:certerror about:config about:crashes about:feeds about:home about:memory about:neterror about:plugins about:pocket-saved about:pocket-signup about:preferences about:privatebrowsing about:sessionrestore about:srcdoc about:support blob: chrome: mediasource: moz-extension: moz-safe-about: resource:");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyAcceptedVersion", 2);
user_pref("distribution.canonical.bookmarksProcessed", true);
user_pref("e10s.rollout.cohort", "disqualified-test");
user_pref("e10s.rollout.cohortSample", "0.026056");
user_pref("experiments.activeExperiment", false);
user_pref("extensions.blocklist.pingCountTotal", 2);
user_pref("extensions.blocklist.pingCountVersion", 2);
user_pref("extensions.bootstrappedAddons", "{\"firefox@getpocket.com\":{\"version\":\"1.0.5\",\"type\":\"extension\",\"descriptor\":\"/usr/lib/firefox/browser/features/firefox@getpocket.com.xpi\",\"multiprocessCompatible\":false,\"runInSafeMode\":true},\"aushelper@mozilla.org\":{\"version\":\"1.0\",\"type\":\"extension\",\"descriptor\":\"/usr/lib/firefox/browser/features/aushelper@mozilla.org.xpi\",\"multiprocessCompatible\":true,\"runInSafeMode\":true},\"e10srollout@mozilla.org\":{\"version\":\"1.5\",\"type\":\"extension\",\"descriptor\":\"/usr/lib/firefox/browser/features/e10srollout@mozilla.org.xpi\",\"multiprocessCompatible\":false,\"runInSafeMode\":true},\"webcompat@mozilla.org\":{\"version\":\"1.0\",\"type\":\"extension\",\"descriptor\":\"/usr/lib/firefox/browser/features/webcompat@mozilla.org.xpi\",\"multiprocessCompatible\":false,\"runInSafeMode\":true},\"langpack-en-ZA@firefox.mozilla.org\":{\"version\":\"50.0.2\",\"type\":\"locale\",\"descriptor\":\"/usr/lib/firefox/browser/extensions/langpack-en-ZA@firefox.mozilla.org.xpi\",\"multiprocessCompatible\":false,\"runInSafeMode\":false},\"langpack-en-GB@firefox.mozilla.org\":{\"version\":\"50.0.2\",\"type\":\"locale\",\"descriptor\":\"/usr/lib/firefox/browser/extensions/langpack-en-GB@firefox.mozilla.org.xpi\",\"multiprocessCompatible\":false,\"runInSafeMode\":false},\"langpack-de@firefox.mozilla.org\":{\"version\":\"50.0.2\",\"type\":\"locale\",\"descriptor\":\"/usr/lib/firefox/browser/extensions/langpack-de@firefox.mozilla.org.xpi\",\"multiprocessCompatible\":false,\"runInSafeMode\":false}}");
user_pref("extensions.databaseSchema", 17);
user_pref("extensions.e10s.rollout.blocklist", "{dc572301-7619-498c-a57d-39143191b318}");
user_pref("extensions.e10s.rollout.hasAddon", false);
user_pref("extensions.e10s.rollout.policy", "50allmpc");
user_pref("extensions.e10sBlockedByAddons", true);
user_pref("extensions.enabledAddons", "ubufox%40ubuntu.com:3.2,%7B73a6fe31-595d-460b-a920-fcc0f8843232%7D:2.9.5.2,%7B972ce4c6-7e08-4474-a285-3208198ce6fd%7D:50.0.2");
user_pref("extensions.getAddons.cache.lastUpdate", 1481025142);
user_pref("extensions.getAddons.databaseSchema", 5);
user_pref("extensions.hotfix.lastVersion", "20160826.01");
user_pref("extensions.lastAppVersion", "50.0.2");
user_pref("extensions.lastPlatformVersion", "50.0.2");
user_pref("extensions.pendingOperations", false);
user_pref("extensions.systemAddonSet", "{\"schema\":1,\"addons\":{}}");
user_pref("extensions.ui.dictionary.hidden", true);
user_pref("extensions.ui.experiment.hidden", true);
user_pref("extensions.ui.lastCategory", "addons://list/extension");
user_pref("extensions.ui.locale.hidden", false);
user_pref("extensions.xpiState", "{\"app-profile\":{\"{73a6fe31-595d-460b-a920-fcc0f8843232}\":{\"d\":\"/home/test/.mozilla/firefox/6zijgpou.default/extensions/{73a6fe31-595d-460b-a920-fcc0f8843232}.xpi\",\"e\":true,\"v\":\"2.9.5.2\",\"st\":1481024901000}},\"app-system-defaults\":{\"firefox@getpocket.com\":{\"d\":\"/usr/lib/firefox/browser/features/firefox@getpocket.com.xpi\",\"e\":true,\"v\":\"1.0.5\",\"st\":1480503816000},\"aushelper@mozilla.org\":{\"d\":\"/usr/lib/firefox/browser/features/aushelper@mozilla.org.xpi\",\"e\":true,\"v\":\"1.0\",\"st\":1480503815000},\"e10srollout@mozilla.org\":{\"d\":\"/usr/lib/firefox/browser/features/e10srollout@mozilla.org.xpi\",\"e\":true,\"v\":\"1.5\",\"st\":1480503815000},\"webcompat@mozilla.org\":{\"d\":\"/usr/lib/firefox/browser/features/webcompat@mozilla.org.xpi\",\"e\":true,\"v\":\"1.0\",\"st\":1480503816000}},\"app-global\":{\"{972ce4c6-7e08-4474-a285-3208198ce6fd}\":{\"d\":\"/usr/lib/firefox/browser/extensions/{972ce4c6-7e08-4474-a285-3208198ce6fd}.xpi\",\"e\":true,\"v\":\"50.0.2\",\"st\":1480503815000},\"langpack-en-ZA@firefox.mozilla.org\":{\"d\":\"/usr/lib/firefox/browser/extensions/langpack-en-ZA@firefox.mozilla.org.xpi\",\"e\":true,\"v\":\"50.0.2\",\"st\":1480504220000},\"langpack-en-GB@firefox.mozilla.org\":{\"d\":\"/usr/lib/firefox/browser/extensions/langpack-en-GB@firefox.mozilla.org.xpi\",\"e\":true,\"v\":\"50.0.2\",\"st\":1480504220000},\"langpack-de@firefox.mozilla.org\":{\"d\":\"/usr/lib/firefox/browser/extensions/langpack-de@firefox.mozilla.org.xpi\",\"e\":true,\"v\":\"50.0.2\",\"st\":1480504215000}},\"app-system-share\":{\"ubufox@ubuntu.com\":{\"d\":\"/usr/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/ubufox@ubuntu.com.xpi\",\"e\":true,\"v\":\"3.2\",\"st\":1442597402000}}}");
user_pref("media.gmp-gmpopenh264.abi", "x86-gcc3");
user_pref("media.gmp-gmpopenh264.lastUpdate", 1481024561);
user_pref("media.gmp-gmpopenh264.version", "1.6");
user_pref("media.gmp-manager.buildID", "20161130094306");
user_pref("media.gmp-manager.lastCheck", 1481024561);
user_pref("media.gmp.storage.version.observed", 1);
user_pref("network.cookie.prefsMigrated", true);
user_pref("network.predictor.cleaned-up", true);
user_pref("noscript.ABE.migration", 1);
user_pref("noscript.gtemp", "");
user_pref("noscript.options.tabSelectedIndexes", "5,2,0");
user_pref("noscript.subscription.lastCheck", -738509754);
user_pref("noscript.temp", "");
user_pref("noscript.version", "2.9.5.2");
user_pref("noscript.visibleUIChecked", true);
user_pref("pdfjs.migrationVersion", 2);
user_pref("pdfjs.previousHandler.alwaysAskBeforeHandling", true);
user_pref("pdfjs.previousHandler.preferredAction", 4);
user_pref("places.history.expiration.transient_current_max_pages", 104858);
user_pref("plugin.disable_full_page_plugin_for_types", "application/pdf");
user_pref("pref.privacy.disable_button.change_blocklist", false);
user_pref("privacy.cpd.offlineApps", true);
user_pref("privacy.cpd.siteSettings", true);
user_pref("privacy.donottrackheader.enabled", true);
user_pref("services.sync.clients.lastSync", "0");
user_pref("services.sync.clients.lastSyncLocal", "0");
user_pref("services.sync.declinedEngines", "");
user_pref("services.sync.globalScore", 0);
user_pref("services.sync.migrated", true);
user_pref("services.sync.nextSync", 0);
user_pref("services.sync.tabs.lastSync", "0");
user_pref("services.sync.tabs.lastSyncLocal", "0");
user_pref("signon.importedFromSqlite", true);

EOF

# Firefox-Profil ins Zielsystem kopieren
# Variante A: den soeben erzeugten Ordner source/skel verwenden
cp -r source/skel squashfs/etc/
# Variante B: Profil aus dem laufenden System verwenden (vorher Bookmarks + Add-ons setzen)
#cp -r $HOME/.mozilla squashfs/etc/skel/

# Menü bauen
mkdir iso/isolinux
cp /mnt/isolinux/boot.cat /mnt/isolinux/isolinux.bin /mnt/isolinux/*.c32 iso/isolinux/

cat > iso/isolinux/isolinux.cfg << EOF
default vesamenu.c32
menu title c't Bankix Lubuntu ${RELEASE}

label ctbankix
  menu label c't Bankix Lubuntu ${RELEASE}
  kernel /casper/vmlinuz
  append BOOT_IMAGE=/casper/vmlinuz boot=casper initrd=/casper/initrd.lz showmounts quiet splash -- debian-installer/language=de console-setup/layoutcode?=de
  
label local
  menu label Betriebssystem von Festplatte starten
  localboot 0x80
EOF

# apt-Pinning um das Einspielen ungepatchter Kernel zu verhindern
cat > squashfs/etc/apt/preferences << EOF
Package: linux-image*
Pin: origin *.ubuntu.com
Pin-Priority: -1

Package: linux-headers*
Pin: origin *.ubuntu.com
Pin-Priority: -1

Package: linux-lts*
Pin: origin *.ubuntu.com
Pin-Priority: -1

Package: linux-generic*
Pin: origin *.ubuntu.com
Pin-Priority: -1
EOF

cat > squashfs/excludes << EOF
casper/*
cdrom/*
cow/*
etc/mtab
home/lubuntu/.cache/*
media/*
mnt/*
proc/*
rofs/*
sys/*
tmp/*
var/log/*
var/cache/apt/archives/*
EOF

#TODO: Initramdisk bauen und an entsprechende Stelle kopieren, sobald gepatchte Kernel bereitstehen

cat > squashfs/usr/sbin/BankixCreateSnapshot.sh << EOF
#!/bin/bash
echo "Snapshot erstellen"
echo "=================="
echo
echo "1. Alle Anwendungen schließen!"
echo "2. Schreibschutzschalter am USB-Stick (sofern vorhanden) auf 'offen' stellen!"
echo
read -r -p "Snapshot jetzt erstellen? [j/N] " questionResponse
if [[ \$questionResponse = [jJ] ]]
then
 echo
 sudo apt-get -y clean
 sudo mount -o remount,rw /cdrom
 sudo mksquashfs / /cdrom/casper/filesystem_new.squashfs -ef /excludes -wildcards
 sudo mv /cdrom/casper/filesystem_new.squashfs /cdrom/casper/filesystem.squashfs
 sudo mount -o remount,ro /cdrom
 echo
 echo "Bitte Taste druecken um das System neu zu starten!"
 read dummy
 sudo reboot
else
 echo
    echo "Es wurde kein Snapshot erstellt!"
    read dummy
fi
EOF
chmod +x squashfs/usr/sbin/BankixCreateSnapshot.sh

mkdir squashfs/etc/skel/Desktop/
cat > squashfs/etc/skel/Desktop/BankixCreateSnapshot.desktop << EOF
[Desktop Entry]
Encoding=UTF-8
Name=Snapshot erstellen
Exec=/usr/sbin/BankixCreateSnapshot.sh
Type=Application
Terminal=true
Icon=/usr/share/icons/Humanity/actions/48/document-save.svg
EOF
chmod +x squashfs/etc/skel/Desktop/BankixCreateSnapshot.desktop

cp /usr/share/applications/lxrandr.desktop squashfs/etc/skel/Desktop/
cp /usr/share/applications/firefox.desktop squashfs/etc/skel/Desktop/
cp /usr/share/applications/update-manager.desktop squashfs/etc/skel/Desktop/

#### System bauen #### END ######


#### Iso erzeugen #### BEGIN ####

zcat squashfs/boot/initrd.img* | lzma -9c > iso/casper/initrd.lz
cp squashfs/boot/vmlinuz* iso/casper/vmlinuz

umount squashfs/dev/pts squashfs/dev squashfs/proc squashfs/sys

#mv squashfs/etc/resolv.conf.orig squashfs/etc/resolv.conf
chroot squashfs/ mv /etc/resolv.conf.original /etc/resolv.conf
chroot squashfs/ mv /etc/apt/sources.list.original /etc/apt/sources.list

mksquashfs squashfs iso/casper/filesystem.squashfs -noappend
genisoimage -cache-inodes -r -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o live.iso iso

isohybrid live.iso

#### Iso erzeugen #### END ######
date
echo
