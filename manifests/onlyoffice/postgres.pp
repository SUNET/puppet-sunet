define sunet::onlyoffice::postgres(
  Optional[String]  $docker_image = "postgres",
  String            $docker_tag   = '9.5',
) {

   
   sunet::docker_run { $name:
      image    => $docker_image,
      imagetag => $docker_tag,
      volumes  => [
                   "/var/lib/postgresql:/var/lib/postgresql"
                  ],
      env      => flatten(["POSTGRES_DB=onlyoffice","POSTGRES_USER=onlyoffice","POSTGRES_HOST_AUTH_METHOD=trust"]),
  }

}
