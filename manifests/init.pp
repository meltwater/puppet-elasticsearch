# Class: elasticsearch
#
# This class installs Elasticsearch
#
# Usage:
# include elasticsearch

class elasticsearch(
  $version     = '0.15.2',
  $xms         = '256m',
  $xmx         = '2048m',
  $user        = 'elasticsearch',
  $basepath    = '/usr/local',
  $javahome    = '/usr/lib/jvm/java',
  $clustername = 'elasticsearch',
  $nodedata    = true,
  $datapath    = 'default',
  $tcpcompress = false,
  $spmkey      = 'none',
  $threadpools = false
) {

  $esBasename       = 'elasticsearch'
  $esName           = "${esBasename}-${version}"
  $esPath           = "${basepath}/elasticsearch"

  if $datapath == 'default' {
    $esDataPath     = "${esPath}/data"
  }
  else {
    $esDataPath     = $datapath
  }

  $esLibPath        = $esDataPath
  $esLogPath        = "/var/log/${esBasename}"
  $esXms            = $xms
  $esXmx            = $xmx
  $esTCPPortRange   = '9300-9399'
  $esHTTPPortRange  = '9200-9299'
  $esUlimitNofile   = '64000'
  $esUlimitMemlock  = 'unlimited'
  $esPidpath        = '/var/run'
  $esPidfile        = "${esPidpath}/${esBasename}.pid"
  $esJarfile        = "${esName}.jar"
  $esTCPCompress    = $tcpcompress

  # SPM settings
  $esSPMkey         = $spmkey
  $esSPMjar         = '/spm/spm-monitor/lib/spm-monitor-es-1.6.0-withdeps.jar'
  $esSPMconfig      = "/spm/spm-monitor/conf/spm-monitor-config-${spmkey}-default.xml"

  file { '/etc/security/limits.d':
    ensure => directory,
    owner  => root,
    group  => root,
  }

  file { "/etc/security/limits.d/${esBasename}.conf":
    ensure  => present,
    content => template('elasticsearch/elasticsearch.limits.conf.erb'),
    owner   => root,
    group   => root,
  }

  # Make sure we have the application path
  file { "${basepath}/src":
    ensure     => directory,
    owner      => $user,
    group      => $user,
  }

  # download and extract archive
  archive { "elasticsearch-${version}":
    url            => "http://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${version}.tar.gz",
    target         => "${basepath}/src",
    src_target     => "${basepath}/src",
    checksum       => false,
    allow_insecure => true,
  }
  ->
  file { "${basepath}/src/elasticsearch-${version}":
    ensure     => directory,
    owner      => $user,
    group      => $user,
    recurse    => true
  }

  # link the new version to the installation dir
  file { $esPath:
    ensure  => link,
    target  => "${basepath}/src/elasticsearch-${version}",
    require => Archive["elasticsearch-${version}"]
  }

  exec { "chown ${esPath}":
    command => "chown -R ${user}: ${esPath}",
    require => File[$esPath]
  }

  case $esDataPath {
    "${esPath}/data": {}
    default: {

      # ensure link to real data path exists
      file { "${esPath}/data":
        ensure  => link,
        force   => true,
        target  => $esDataPath,
        require => File[$esDataPath],
      }
    }
  }

  # Ensure the data path is created
  file { $esDataPath:
    ensure  => directory,
    owner   => $user,
    group   => $user,
    require => File[$esPath],
  }

  # Symlink config to /etc
  file { "/etc/${esBasename}":
    ensure  => link,
    target  => "${esPath}/config",
    require => Archive["elasticsearch-${version}"],
  }

  # Apply config template for search
  file { "${esPath}/config/elasticsearch.yml":
    content => template('elasticsearch/elasticsearch.yml.erb'),
    require => File["/etc/${esBasename}"],
  }

  #Apply logging template for search
  file { "${esPath}/config/logging.yml":
    content => template('elasticsearch/logging.yml.erb'),
    require => File["/etc/${esBasename}"],
  }

  # Create startup script
  file { '/etc/init.d/elasticsearch':
    content => template('elasticsearch/elasticsearch.init.d.erb'),
    owner   => root,
    group   => root,
    mode    => '0744',
  }

  # Apply startup config shell script
  file { "${esPath}/bin/elasticsearch.in.sh":
    content => template('elasticsearch/elasticsearch.in.sh.erb'),
    require => File["/etc/${esBasename}"],
  }

  # Ensure logging directory
  file { $esLogPath:
    ensure    => directory,
    owner     => $user,
    group     => $user,
    recurse   => true,
    require   => Archive["elasticsearch-${version}"],
  }

  file { "${esPath}/logs":
    ensure  => link,
    target  => $esLogPath,
    force   => true,
    require => File[$esLogPath],
  }

  # Ensure the service is running
  service { $esBasename:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => [ File["${esPath}/logs"], File["${esPath}/config/elasticsearch.yml"] ],
  }

}
