# Class: elasticsearch
#
# This class installs Elasticsearch
#
# Usage:
# include elasticsearch

class elasticsearch( $version = "0.15.2", $xmx = "2048m", $user = "elasticsearch", $basepath = "/usr/local", $javahome = "/usr/lib/jvm/java" ) {
      $esBasename       = "elasticsearch"
      $esName           = "${esBasename}-${version}"
      $esPath           = "${basepath}/${esName}"
      $esDataPath       = "${basepath}/${esBasename}/data"
      $esLibPath        = "${esDataPath}"
      $esLogPath        = "/var/log/${esBasename}"
      $esXms            = "256m"
      $esXmx            = "${xmx}"
      $cluster          = "${name}"
      $esTCPPortRange   = "9300-9399"
      $esHTTPPortRange  = "9200-9299"
      $esUlimitNofile   = "32000"
      $esUlimitMemlock  = "unlimited"
      $esPidpath        = "/var/run"
      $esPidfile        = "${esPidpath}/${esBasename}.pid"
      $esJarfile        = "${esName}.jar"
      

     file { "/etc/scurity/limits.d":
         ensure => directory,
         owner => root,
         group => root,
     }

     file { "/etc/security/limits.d/${esBasename}.conf":
          content => template("elasticsearch/elasticsearch.limits.conf.erb"),
          ensure => present,
          owner => root,
          group => root,
     }

     # Make sure we have the application path
     file { "$basepath/src":
             ensure     => directory,
             require    => User["$user"],
             owner      => "$user",
             group      => "$user", 
             recurse    => true
      }
      
      # download and extract archive
      archive { "elasticsearch-#{version}":
        url => "https://github.com/downloads/elasticsearch/elasticsearch/elasticsearch-#{version}.tar.gz",
        target => "$basepath/src",
        src_target => "$basepath/src",
        checksum => false,
        require  => File["$esPath"],
      }

      # link the new version to the installation dir
      file { "$esPath":
        ensure  => link,
        target => "$basepath/src/elasticsearch-$version",
        require => Archive["elasticsearch-$version"]
      }

      # Ensure the data path is created
      file { "$esDataPath":
           ensure => directory,
           owner  => "$esUser",
           group  => "$esUser",
           require => File["$esPath"],
           recurse => true
      }

      # Ensure the link to the data path is set
      file { "$esPath/data":
           ensure => link,
           force => true,
           target => "$esDataPath",
           # skip if data path is in es directory
           unless => "test -d ${esPath}/data",
           require => File["$esDataPath"],
      }
      
      # Symlink config to /etc
      file { "/etc/$esBasename":
             ensure => link,
             target => "$esPathLink/config",
             require => Archive["elasticsearch-$version"],
      }

      # Apply config template for search
      file { "$esPath/config/elasticsearch.yml":
             content => template("elasticsearch/elasticsearch.yml.erb"),
             require => File["/etc/$esBasename"]      
      }
      
      # Create startup script
      file { "/etc/init.d/elasticsearch":
           template => "elasticsearch/elasticsearch.init.d.erb",
           owner  => root,
           group  => root,
           mode   => 744,
      }
      
      # Ensure logging directory
      file { "$esLogPath":
           owner     => "$esBasename",
           group     => "$esBasename",
           ensure    => directory,
           recurse   => true,
           require => Archive["elasticsearch-$version"],
      }
      
      # Ensure logging link is in place
      file { "/var/log/$esBasename":
           ensure => link,
           target => "$esLogPath",
           require => [File["${esLogPath}"], File["/etc/init.d/$esBasename"]]
      }

      file { "$esPath/logs":
           ensure => link,
           target => "/var/log/$esBasename",
           force => true,
           require => File["/var/log/$esBasename"]
      }
            
      # Ensure the service is running
      service { "$esBasename":
            enable => true,
            ensure => running,
            hasrestart => true,
            require => File["$esPath/logs"]
      }

}
