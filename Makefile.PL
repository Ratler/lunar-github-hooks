use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Lunar::GitHUB',
    AUTHOR              => q{Stefan Wold <ratler@lunar-linux.org>},
    VERSION_FROM        => 'lib/Lunar/GitHUB.pm',
    ABSTRACT            => 'Lunar Linux GitHUB Post Receive Hook',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.3096,
        'LWP::Protocol::https' => 0,
        'Mail::Sendmail' => 0,
        'DateTime::Format::Strptime' => 0,
        'DateTime::Format::ISO8601' => 0,
        'Data::Dumper' => 0,
        'JSON' => 0,
    },
    META_MERGE => {
      'resources' => {
        'repository' => ''
      }
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Lunar-GitHUB-*' },
);
