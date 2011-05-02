# Class: postgres
#
# This module manages postgres
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage: see postgres/README.markdown
#
# [Remember: No empty lines between comments and class definition]
class postgres {
  # Common stuff, like ensuring postgres_password defined in site.pp
  include postgres::common

  package { [$postgres::common::client, $postgres::common::server]: 
    ensure => installed,
  }

  user { 'postgres':
    shell => '/bin/bash',
    ensure => 'present',
    comment => operating_system ? {
      /(?i-mx:centos|fedora|redhat)/ => 'PostgreSQL Server',
      /(?i-mx:debian|ubuntu)/ => 'PostgreSQL administrator',
      default => 'PostgreSQL administrator'
    },
    uid => operating_system ? {
      /(?i-mx:centos|fedora|redhat)/ => 26,
      default => undef
    },
    gid => operating_system ? {
      /(?i-mx:centos|fedora|redhat)/ => 26,
      default => 'postgres'
    },
    home => $postgres::common::homedir,
    managehome => true,
    password => '!!',
  }

  group { 'postgres':
    ensure => 'present',
    gid => operating_system ? {
      /(?i-mx:centos|fedora|redhat)/ => 26,
      default => undef
    },
  }

}

# Initialize the database with the postgres_password password.
define postgres::initdb() {
  include postgres::common
  if $postgres_password == "" {
    exec {
        "InitDB":
          command => "/bin/chown postgres.postgres ${postgres::common::datadir} && /bin/su postgres -c \"/usr/bin/initdb ${postgres::common::datadir} -E UTF8\"",
          require =>  [User['postgres'],Package[$postgres::common::server]],
          unless => "/usr/bin/test -e ${postgres::common::datadir}/PG_VERSION",
    }
  } else {
    exec {
        "InitDB":
          command => "/bin/chown postgres.postgres ${postgres::common::datadir} && echo \"${postgres_password}\" > /tmp/ps && /bin/su  postgres -c \"/usr/bin/initdb ${postgres::common::datadir} --auth='password' --pwfile=/tmp/ps -E UTF8 \" && rm -rf /tmp/ps",
          require =>  [User['postgres'],Package[$postgres::common::server]],
          unless => "/usr/bin/test -e ${postgres::common::datadir}/PG_VERSION ",
    }
  }
}

# Start the service if not running
define postgres::enable {
  service { postgresql:
    ensure => running,
    enable => true,
    hasstatus => true,
    require => Exec["InitDB"],
  }
}


# Postgres host based authentication 
define postgres::hba ($postgres_password="",$allowedrules){
  include postgres::common
  file { "${postgres::common::datadir}/pg_hba.conf":
    content => template("postgres/pg_hba.conf.erb"),	
    owner  => "root",
    group  => "root",
    notify => Service["postgresql"],
 #   require => File["/var/lib/pgsql/.order"],
    require => Exec["InitDB"],
  }
}

define postgres::config ($listen="localhost")  {
  include postgres::common
  file {"${postgres::common::datadir}/postgresql.conf":
    content => template("postgres/postgresql.conf.erb"),
    owner => postgres,
    group => postgres,
    notify => Service["postgresql"],
  #  require => File["/var/lib/pgsql/.order"],
    require => Exec["InitDB"],
  }
}

# Base SQL exec
define sqlexec($username, $password, $database, $sql, $sqlcheck) {
  if $postgres_password == "" {
    exec{ "psql -h localhost --username=${username} $database -c \"${sql}\" >> /var/lib/puppet/log/postgresql.sql.log 2>&1 && /bin/sleep 5":
      path        => $path,
      timeout     => 600,
      unless      => "psql -U $username $database -c $sqlcheck",
      require =>  [User['postgres'],Service[postgresql]],
    }
  } else {
    exec{ "psql -h localhost --username=${username} $database -c \"${sql}\" >> /var/lib/puppet/log/postgresql.sql.log 2>&1 && /bin/sleep 5":
      environment => "PGPASSWORD=${postgres_password}",
      path        => $path,
      timeout     => 600,
      unless      => "psql -U $username $database -c $sqlcheck",
      require =>  [User['postgres'],Service[postgresql]],
    }
  }
}

# Create a Postgres user
define postgres::createuser($passwd) {
  sqlexec{ createuser:
    password => $postgres_password, 
    username => "postgres",
    database => "postgres",
    sql      => "CREATE ROLE ${name} WITH LOGIN PASSWORD '${passwd}';",
    sqlcheck => "\"SELECT usename FROM pg_user WHERE usename = '${name}'\" | grep ${name}",
    require  =>  Service[postgresql],
  }
}

# Create a Postgres db
define postgres::createdb($owner) {
  sqlexec{ $name:
    password => $postgres_password, 
    username => "postgres",
    database => "postgres",
    sql => "CREATE DATABASE $name WITH OWNER = $owner ENCODING = 'UTF8';",
    sqlcheck => "\"SELECT datname FROM pg_database WHERE datname ='$name'\" | grep $name",
    require => Service[postgresql],
  }
}
