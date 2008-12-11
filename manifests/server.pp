class backupninja::server {

  $real_backupdir = $backupdir ? {
    '' => "/backup",
    default => $backupdir,
  }
  $real_usermanage = $usermanage ? {
    '' => 'doit',
    default => $usermanage
  }
  $real_backupserver_tag = $backupserver_tag ? {
    '' => $fqdn,
    default => $backupserver_tag
  }

  group { "backupninjas":
    ensure => "present",
    gid => 700
  }
  
  file { "$real_backupdir":
    ensure => "directory",
    mode => 0710, owner => root, group => "backupninjas"
  }
  
  User <<| tag == "backupninja-$real_backupserver_tag" |>>
  File <<| tag == "backupninja-$real_backupserver_tag" |>>

  package { [ "rsync", "rdiff-backup" ]: ensure => installed }

  # this define allows nodes to declare a remote backup sandbox, that have to
  # get created on the server
  define sandbox(
    $user = false, $host = false, $installuser = true, $dir = false, $manage_ssh_dir = true,
    $ssh_dir = false, $authorized_keys_file = false, $backupkeys = false, $uid = false,
    $gid = "backupninjas", $backuptag = false)
  {
    
    $real_user = $user ? {
      false => $name,
      default => $user,
      '' => $name,
    }
    $real_host = $host ? {
      false => $fqdn,
      default => $host,
    }
    $real_backupkeys = $backupkeys ? {
      false => "$fileserver/keys/backupkeys",
      default => $backupkeys,
    }
    $real_dir = $dir ? {
      false => "${backupninja::server::real_backupdir}/$fqdn",
      default => $dir,
    }
    $real_ssh_dir = $ssh_dir ? {
      false => "${real_dir}/.ssh",
      default => $ssh_dir,
    }
    $real_authorized_keys_file = $authorized_keys_file ? {
      false => "authorized_keys",
      default => $authorized_keys_file,
    }
    $real_backuptag = $backuptag ? {
      false => "backupninja-$real_host",
      default => $backuptag,
    }
      
    @@file { "$real_dir":
      ensure => directory,
      mode => 0750, owner => $real_user, group => 0,
      tag => "$real_backuptag",
    }
    case $installuser {
      true: {
        case $manage_ssh_dir {
          true: {
            @@file { "${real_ssh_dir}":
              ensure => directory,
              mode => 0700, owner => $real_user, group => 0,
              require => File["$real_dir"],
              tag => "$real_backuptag",
            }
          }
        } 
        @@file { "${real_ssh_dir}/${real_authorized_keys_file}":
          ensure => present,
          mode => 0644, owner => 0, group => 0,
          source => "$real_backupkeys/${real_user}_id_rsa.pub",
          require => File["${real_ssh_dir}"],
          tag => "$real_backuptag",
        }
        case $uid {
          false: {
            @@user { "$real_user":
              ensure  => "present",
              gid     => "$gid",
              comment => "$name backup sandbox",
              home    => "$real_dir",
              managehome => true,
              shell   => "/bin/sh",
              password => '*',
	      require => [ Group['backupninjas'], File["$real_dir"] ],
              tag => "$real_backuptag"
            }
          }
          default: {
            @@user { "$real_user":
              ensure  => "present",
              uid     => "$uid",
              gid     => "$gid",
              comment => "$name backup sandbox",
              home    => "$real_dir",
              managehome => true,
              shell   => "/bin/sh",
              password => '*',
	      require => [ Group['backupninjas'], File["$real_dir"] ],
              tag => "$real_backuptag"
            }
          }
        }
      }
    }
  }
}

