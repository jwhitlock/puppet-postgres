# Class: postgres::common
#
# Common stuff across postgres class
#
# Parameters:
#
# Actions:
#
# Requires:
#
# [Remember: No empty lines between comments and class definition]
class postgres::common {
  # If you wish, you can uncomment the below to
  # fail the update if postgres_password not set in site.pp
  
  #case $postgres_password {
  #  "": { fail("postgres_password must be set!")
  #  }
  #}

  #case $postgres_version {
  #  "": { fail("postgres_version must be set!")
  #  }
  #}

  if ("${postgres_version}" == "") {
    case $operatingsystem {
     /(?i-mx:ubuntu|debian)/: { fail("postgres_version must be set!") }
    }
  }
  # Define some variables
  $client = $operatingsystem ? {
    /(?i-mx:ubuntu|debian)/ => "postgresql-client-${postgres_version}",
    /(?i-mx:centos|fedora|redhat)/ => "postgresql${postgres_version}",
    default => "postgresql${postgres_version}"
  }
  $server = $operatingsystem ? {
    /(?i-mx:ubuntu|debian)/ => "postgresql-${postgres_version}",
    /(?i-mx:centos|fedora|redhat)/ => "postgresql${postgres_version}-server",
    default => "postgresql${postgres_version}-server"
  }
  $homedir = $operatingsystem ? {
    /(?i-mx:centos|fedora|redhat)/ => '/var/lib/pgsql',
    /(?i-mx:debian|ubuntu)/ => '/var/lib/postgresql',
    default => '/var/lib/pgsql'
  }
  $datadir = $operatingsystem ? {
    /(?i-mx:centos|fedora|redhat)/ => $homedir,
    /(?i-mx:debian|ubuntu)/ => "${homedir}/${postgres_version}/main", 
    default => $homedir
  }
}
