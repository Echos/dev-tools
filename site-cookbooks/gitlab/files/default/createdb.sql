CREATE USER 'gitlab'@'localhost' IDENTIFIED BY 'gitlab';
CREATE DATABASE IF NOT EXISTS `gitlabhq_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;
GRANT SELECT,  INSERT,  UPDATE,  DELETE,  CREATE,  DROP,  INDEX,  ALTER ON `gitlabhq_production`.* TO 'gitlab'@'localhost';
