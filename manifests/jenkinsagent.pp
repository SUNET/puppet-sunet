class sunet::jenkinsagent(
  String $agentname,
  String $jenkins_image = "docker.sunet.se/jenkins/testautomation-agent", 
  String $jenkins_tag   = "sunet-test-agent-1",
  String $url           = "https://testautomation.drive.sunet.dev"
)
{
  $jsecret=lookup('jsecret')
  # Compose
  sunet::docker_compose { 'jenkins_agent':
    content          => template('sunet/jenkinsagent/docker-compose.yaml.erb'),
    service_name     => 'jenkinsagent',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yaml',
    description      => 'Jenkins Testautomation Agent Services',
  }
}
