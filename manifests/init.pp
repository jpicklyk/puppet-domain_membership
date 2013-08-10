# == Class: domain_membership
#
# Full description of class domain_membership here.
#
# === Parameters
#
# Document parameters here.
#
# [*domain*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
# [*username*]
#
# === Examples
#
#  class { domain_membership:
#    domain => 'pupetlabs.lan',
#  }
#
# === Authors
#
# Thomas Linkin <tom@puppetlabs.com>
#
# === Copyright
#
# Copyright 2013 Thomas Linkin, unless otherwise noted.
#
class domain_membership (
  $domain,
  $username,
  $password,
  $secure_password = false,
  $machine_ou      = undef,
  $force           = false,
  $resetpw         = true,
){

  # Validate Parameters
  validate_string($username)
  validate_string($password)
  validate_bool($force)
  validate_bool($resetpw)
  unless is_domain_name($domain) {
    fail('Class[domain_membership] domain parameter must be a valid rfc1035 domain name')
  }

  # Use Either a "Secure String" password or an unencrypted password
  if $secure_password {
    $_password = "(New-Object System.Management.Automation.PSCredential('user',(convertto-securestring '${password}'))).GetNetworkCredential().password"
  }else{
    $_password = "'$password'"
  }

  # Allow an optional OU location for the creation of the machine
  # account to be specified. If unset, we use the powershell representation
  # of nil, which is the `$null` variable.
  if $machine_ou {
    validate_string($machine_ou)
    $_machine_ou = "'${machine_ou}'"
  }else{
    $_machine_ou = '$null'
  }

  # $force toggles between two types of joins, these are just a small selection
  # from the overall set of join choices.
  #
  # 32 (0x20) Allows a join to a new domain, even if the computer is already joined to a domain.
  # 1 (0x1)   Default. Joins a computer to a domain. If this value is not specified, the join is a computer to a workgroup.
  if $force {
    $fjoinoption = '32'
  }else{
    $fjoinoption = '1'
  }

  # Since the powershell command is combersome, we'll construct it here for clarity... well, almost clarity
  #
  $command = "(Get-WmiObject -Class Win32_ComputerSystem).JoinDomainOrWorkGroup('${domain}',${_password},'${username}@${domain}',${_machine_ou},${fjoinoption})"

  exec { 'join_domain':
    command  => $command,
    unless   => "if((Get-WmiObject -Class Win32_ComputerSystem).domain -ne '${domain}'){ exit 1 }",
    provider => powershell,
  }

  if $resetpw {
    exec { 'reset_computer_trust':
      command  => "netdom /RESETPWD /UserD:${username} /PasswordD:${_password} /Server:${domain}",
      unless   => "if ($(nltest /sc_verify:${domain}) -match 'ERROR_INVALID_PASSWORD') {exit 1}",
      provider => powershell,
      require  => Exec['join_domain'],
    }
  }
}
