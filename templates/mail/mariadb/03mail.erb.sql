CREATE DATABASE IF NOT EXISTS mailserver;
CREATE TABLE `mailserver`.`virtual_domains` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `mailserver`.`virtual_users` (
  `id` int(11) NOT NULL auto_increment,
  `domain_id` int(11) DEFAULT 1,
  `password` varchar(256) NOT NULL,
  `email` varchar(100) NOT NULL,
  `comment` varchar(100) DEFAULT 'Manually added',
  `hash` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `mailserver`.`virtual_aliases` (
  `id` int(11) NOT NULL auto_increment,
  `domain_id` int(11) NOT NULL,
  `source` varchar(100) NOT NULL,
  `destination` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE USER IF NOT EXISTS `postfix`@`%` IDENTIFIED BY '<%= @postfix_password %>';
GRANT ALL ON mailserver.* to `postfix`@`%`;
