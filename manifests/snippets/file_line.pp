# from http://projects.puppetlabs.com/projects/puppet/wiki/Simple_Text_Patterns/5
define sunet::snippets::file_line($filename, $line, $ensure = 'present') {
  case $ensure {
    default : { err ( "unknown ensure value ${ensure}" ) }
    present: {
      exec { "/bin/echo '${line}' >> '${filename}'":
        unless => "/bin/grep -qFx '${line}' '${filename}'"
      }
    }
    absent: {
      exec { "/usr/bin/perl -ni -e 'print unless /^\\Q${line}\\E\$/' '${filename}'":
        onlyif => "/bin/grep -qFx '${line}' '${filename}'"
      }
    }
    uncomment: {
      exec { "/bin/sed -i -e'/${line}/s/^#\\+//' '${filename}'":
        onlyif => "/bin/grep '${line}' '${filename}' | /bin/grep '^#' | /usr/bin/wc -l"
      }
    }
    comment: {
      exec { "/bin/sed -i -e'/${line}/s/^\\(.\\+\\)$/#\\1/' '${filename}'":
        onlyif => "/usr/bin/test `/bin/grep '${line}' '${filename}' | /bin/grep -v '^#' | /usr/bin/wc -l` -ne 0"
      }
    }
  }
}
