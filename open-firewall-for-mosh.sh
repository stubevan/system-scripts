# i recommend setting up the following alias first
alias firepower='sudo /usr/libexec/ApplicationFirewall/socketfilterfw'

# temporarily shut firewall off
firepower --setglobalstate off

# add symlinked location to firewall
firepower --add $(which mosh-server)
firepower --unblockapp $(which mosh-server)

# add homebrew location to firewall
firepower --add /usr/local/Cellar/mosh/1.3.2_5/bin/mosh-server
firepower --unblockapp /usr/local/Cellar/mosh/1.3.2_5/bin/mosh-server

# re-enable firewall
firepower --setglobalstate on
