define sunet::onlyoffice::docs(
  Integer           $port         = 80,
  Integer           $tls_port     = 443,
  Optional[String]  $docker_image = "onlyoffice/documentserver",
  String            $docker_tag   = 'latest',
  String            $basedir      = "/opt/onlyoffice/docs/${name}",
  String            $hostname     = $::fqdn,
  Enum['yes', 'no'] $letsencrypt  = 'no',
  Optional[String]  $contact_mail = "noc@sunet.se",
  ) {

  file {[$basedir,"$basedir/logs","$basedir/data","$basedir/data/certs",
         "$basedir/lib","$basedir/db"]: ensure => directory }
 
  $le_env = $letsencrypt ? {
     'no'    => [],
     default => ["LETS_ENCRYPT_DOMAIN=$hostname","LETS_ENCRYPT_MAIL=$contact_mail"]
  }

  $jwt_secret = safe_hiera('onlyoffice_jwt_secret',undef)
  $jwt_env = $jwt_secret = {
     undef   => [],
     default => ["JWT_ENABLED=yes","JWT_SECRET=$jwt_secret"]
  }

  exec {"${name}_create_dhparam":
     command => "/usr/bin/openssl dhparam -out $basedir/data/certs/dhparam.pem 2048",
     unless  => "/usr/bin/test -s $basedir/data/certs/dhparam.pem"
  } ->

  sunet::docker_run { $name:
      image    => $docker_image,
      imagetag => $docker_tag,
      volumes  => [
                   "$basedir/logs:/var/log/onlyoffice",
                   "$basedir/data:/var/www/onlyoffice/Data",
                   "$basedir/lib:/var/lib/onlyoffice",
                   "$basedir/db:/var/lib/postgresql"
                  ],
      ports    => ["$port:80","$tls_port:443"],
      env      => flatten([$le_env,$jwt_env]),
  }
}
