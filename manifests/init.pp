# == Class: domain_membership
#
# Full description of class domain_membership here.
#
# === Parameters
#
# [*domain*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
# [*username*]
#   Username of domain user with machine join privileges.
# [*password*]
#   Password for domain user. This can optionally be passed as a "Secure
#   String" if the `$secure_password` parameter is true.
# [*machine_ou*]
#   OU in the domain to create the machine account in. This is used durring
#   the initial join process. It cannot move the machine account later on.
# [*force*]
#   Forces the machine to join a new domain even if it has prior membership
#   to other domains. Valid values are `true` and `false`. Defaults to `false`.
# [*resetpw*]
#   Whether or not to force a machine password reset if for some reason the trust
#   between the domain and the machine becomes unsyncronized. Valid values are `true`
#   and `false`. Defaults to `true`.
# [*join_options*]
#   A bit flag for setting options for joining a domain.
#   See: http://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx
#   Defaults to '1'.
#
# === Examples
#
#  class { domain_membership:
#    domain        => 'pupetlabs.lan',
#    username      => 'administrator',
#    password      => 'fake5ecret',
#    force         => true,
#    join_options  => '3',
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
  $machine_ou      = undef,
  $resetpw         = false,
  $join_options     = undef,
){

  # Validate Parameters
  validate_string($username)
  validate_string($password)
  validate_bool($resetpw)
  
  unless is_domain_name($domain) {
    fail('Class[domain_membership] domain parameter must be a valid rfc1035 domain name')
  }

  $credential = "(New-Object System.Management.Automation.PsCredential(\'${username}@${domain}\', (ConvertTo-SecureString \'${password}\' -AsPlainText -Force)))"

  # Allow an optional OU location for the creation of the machine
  # account to be specified. 
  if $machine_ou {
    validate_string($machine_ou)
    $ou_flag = "-OUPath '${machine_ou}'"
  }else{
    $ou_flag = ''
  }

  exec { 'join_domain':
    command  => "Add-Computer -DomainName ${domain} -Credential ${credential} ${ou_flag}",
    unless   => "[System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name -eq '${domain}')",
    provider => powershell,
  }

  if $resetpw {
    exec { 'reset_computer_trust':
      command  => "Reset-ComputerMachinePassword -Credential $credential",
      unless   => "Test-ComputerSecureChannel", #can take ~60s if no DC is reachable
      provider => powershell,
      require  => Exec['join_domain'],
    }
  }
}
