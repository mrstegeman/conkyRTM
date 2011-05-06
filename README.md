# Description:

conkyRTM can be used to output one or several task list(s) from Remember the Milk into Conky, with formatting. 

# Basic Usage:

`./conkyRTM.pl -u USER -p PASSWORD`

# Conky Usage:

`${execpi 3600 perl /path/to/conkyRTM.pl -u USER -p PASS [options]}`

# Requirements:

* HTML::Entities
   * http://search.cpan.org/~gaas/HTML-Parser-3.68/lib/HTML/Entities.pm
* Date::Calc
   * http://search.cpan.org/~stbey/Date-Calc-6.3/lib/Date/Calc.pod
* DateTime
   * http://search.cpan.org/~drolsky/DateTime/lib/DateTime.pm
* DateTime::Format::Strptime
   * http://search.cpan.org/~drolsky/DateTime-Format-Strptime/lib/DateTime/Format/Strptime.pm
