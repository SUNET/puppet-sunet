#
# sunet::dracut::no_shutdown_initramfs
#
# Path in the sunet module: manifests/dracut/no_shutdown_initramfs.pp
#
# OPT-IN. Does nothing unless explicitly enabled in Hiera:
#
#   sunet::dracut::no_shutdown_initramfs::enable: true
#
# Included from sunet::tools, next to the molly-guard package that makes it
# necessary, so it is available everywhere - but only acts where we have turned
# it on. Set it per host, or for a group such as all baremetal servers.
#
#
# WHAT PROBLEM THIS SOLVES
# ------------------------
# Ubuntu 26.04 builds the initramfs with dracut instead of the old
# initramfs-tools. dracut adds a "shutdown initramfs": on hosts with complex
# storage (md RAID, LVM, multipath, dm-crypt) a copy of the boot-time initramfs
# is kept in /run/initramfs, and at reboot the system switches root into it to
# finish teardown. That mini-environment is then responsible for issuing the
# actual reboot, by running the `reboot` command inside itself.
#
# molly-guard (installed fleet-wide by sunet::tools) diverts /usr/sbin/reboot to
# a shell script at /usr/lib/molly-guard/molly-guard. dracut copies the
# *symlink* into the initramfs but not the script it points at, so inside the
# mini-environment `reboot` is a link to nothing:
#
#     E: not a regular file:
#     dracut Warning: reboot failed!
#     Dropping to debug shell.
#
# The host has unmounted everything by then, so no data is at risk - but it sits
# at a debug prompt until someone does a physical or BMC reset. Upstream bug:
# https://bugs.debian.org/992351 (open since 2021, re-reported for trixie)
#
# This never bit us on Ubuntu 24.04 and older because initramfs-tools does not
# do the switch-back-at-shutdown with copied commands. It is purely a dracut-era
# issue, and it only fires where something requests a shutdown initramfs - hence
# our physical servers (md RAID + multipath + LUKS swap) and not our plain
# single-disk VMs, which never request one.
#
# WHY THIS FIX
# ------------
# On hosts whose root is on local storage there is nothing that needs doing
# after root is unmounted, so the shutdown initramfs buys us nothing. We tell
# dracut not to build it, and mask finalrd (which assembles /run/initramfs at
# shutdown and was failing halfway with 73/CANTCREAT against the dracut tree,
# leaving a half-built environment to switch into). systemd then performs the
# reboot in-process and never runs the `reboot` command at all - so molly-guard
# stays fully installed and keeps prompting interactive admins, but it is out of
# the automated shutdown path entirely.
#
# The alternative - teaching dracut to install molly-guard and its dependencies
# into the initramfs - was rejected: molly-guard is a shell script whose only
# job is to interact with a human, and there is no human in the shutdown
# environment. If we ever need the shutdown initramfs back (network-backed root)
# the right approach is a dracut module that puts the *real* reboot binaries
# into the image under the canonical names, bypassing molly-guard there.
#
# WHEN TO ENABLE IT
# -----------------
# Enable on a host that has, or will have, complex storage on a release where
# this bug is present (Ubuntu 26.04 as of writing). To identify an affected host
# without rebooting it:
#
#   [ -x /run/initramfs/shutdown ] && readlink -f /usr/sbin/reboot \
#     | grep -q molly-guard && echo "AT RISK: $(hostname)"
#
# Both conditions must hold to hang: a shutdown initramfs was prepared at boot,
# and `reboot` points at molly-guard.
#
# DO NOT ENABLE where root or /usr lives on network storage - iSCSI, NBD, FCoE
# or NFS root. Those genuinely need the shutdown initramfs, because you cannot
# unmount root and then tear down the network from inside root itself.
#
# Being opt-in, this is also self-limiting across releases: nothing carries over
# to 28.04 unless someone confirms the bug is still there and enables it again.
#
class sunet::dracut::no_shutdown_initramfs (

  # Master switch - opt-in, so this class is inert by default.
  Boolean $enable = false,

  # finalrd is the helper that populates /run/initramfs at shutdown. With no
  # shutdown module it has nothing useful to do, and its half-built tree is what
  # the system ends up switching into - so we mask it. Separable in case a
  # future node needs finalrd for its own reasons.
  Boolean $manage_finalrd = true,

  # dracut reads every *.conf in this directory in sorted order, and 99- puts us
  # last so we win over anything the distro or another module drops in.
  # Typed as String[1] rather than Stdlib::Absolutepath so this class carries no
  # dependency on puppetlabs-stdlib.
  String[1] $conf_path =
    '/etc/dracut.conf.d/99-no-shutdown-initramfs.conf',

) {

  if $enable {

    file { $conf_path:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => @("EOT"/L),
        # Managed by Puppet - sunet::dracut::no_shutdown_initramfs
        #
        # molly-guard diverts /usr/sbin/reboot to a shell script that dracut
        # cannot install into the initramfs, leaving a dangling symlink and
        # "dracut Warning: reboot failed!" on every reboot (Debian #992351).
        # Root here is local storage, so no switched-root teardown is needed:
        # drop the shutdown initramfs and let systemd reboot in-process.
        omit_dracutmodules+=" shutdown "
        | EOT
      notify  => Exec['regenerate-initramfs-bootable-kernels'],
    }

    # Regenerate the initramfs so the change takes effect on the *currently
    # installed* kernels. Future kernel upgrades need no help: the packaged
    # upgrade path runs dracut, which reads /etc/dracut.conf.d/ and will already
    # omit the shutdown module.
    #
    # update-initramfs here is dracut's own compatibility wrapper (owned by the
    # `dracut` package, verified with dpkg -S, no dpkg diversions involved), so
    # it writes to the Ubuntu paths /boot/initrd.img-<version> that GRUB
    # actually reads. initramfs-tools proper is not installed; only its shared
    # -core and -bin packages are, which dracut itself depends on.
    #
    # Two deliberate choices here:
    #
    # 1. NOT `dracut --regenerate-all`. That iterates /usr/lib/modules/* and
    #    writes to the kernel-install/BLS layout /boot/efi/<machine-id>/<ver>/,
    #    which does not exist on our GRUB-booted hosts - every kernel fails with
    #    "Can't write to /boot/efi/...". update-initramfs knows the right paths.
    #
    # 2. NOT `update-initramfs -u -k all`. That also walks /usr/lib/modules/*,
    #    which on long-lived hosts contains orphaned trees from kernels removed
    #    months ago (dpkg leaves behind depmod-generated files it did not
    #    install, so the directory survives the purge). Building an initramfs
    #    for a kernel that has no vmlinuz fails and would make this exec error
    #    out on otherwise healthy nodes. So we select kernels by what is
    #    actually bootable: a /boot/vmlinuz-* WITH a matching module tree.
    #
    # refreshonly: runs when the config file above is created or changed, not on
    # every Puppet run.
    exec { 'regenerate-initramfs-bootable-kernels':
      command     => @(EOC/L),
        /bin/bash -c 'set -e; \
        for vmlinuz in /boot/vmlinuz-*; do \
          [ -e "$vmlinuz" ] || continue; \
          kver=${vmlinuz#/boot/vmlinuz-}; \
          [ -d "/usr/lib/modules/$kver" ] || continue; \
          /usr/sbin/update-initramfs -u -k "$kver"; \
        done'
        | EOC
      refreshonly => true,
      timeout     => 900,
      path        => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      logoutput   => true,
    }

    if $manage_finalrd {
      service { 'finalrd':
        ensure => 'stopped',
        enable => 'mask',
      }
    }
  }
}

# -----------------------------------------------------------------------------
# NOT FIXED BY THIS CLASS, deliberately - noted here so the next person does not
# go looking:
#
#  * Orphaned /usr/lib/modules/* trees and `rc`-state linux-* packages. Inert;
#    they only mean `-k all` cannot be used, which is why the exec above selects
#    kernels explicitly. Clean up in a general tidy-up, not here.
#
#  * kernel-install auto-detecting a BLS layout on GRUB hosts (see choice 1
#    above). An explicit `layout=other` in /etc/kernel/install.conf would stop
#    the guessing, but the packaged kernel-upgrade path works regardless, so it
#    is cosmetic.
#
# VERIFYING A NODE after this class has applied and the node has rebooted:
#
#   ls -la /run/initramfs                    # may hold logs and .need_shutdown;
#                                            # must NOT contain an executable
#                                            # 'shutdown'
#   systemctl is-enabled finalrd.service     # masked
#   cat /proc/mdstat                         # no unexpected resync
#   journalctl -b | grep -iE 'recovering journal|unclean'
#
# TO REVERT on a node: set enable: false in Hiera (which stops Puppet managing
# it but does not undo it), then by hand:
#
#   rm -f /etc/dracut.conf.d/99-no-shutdown-initramfs.conf
#   systemctl unmask finalrd.service
#   for v in /boot/vmlinuz-*; do update-initramfs -u -k "${v#/boot/vmlinuz-}"; done
#
# Note that reverting reinstates the hang on any host that still has
# molly-guard and complex storage - so have BMC access.
# -----------------------------------------------------------------------------
