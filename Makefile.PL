use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'NCBI::Taxonomy',
    VERSION_FROM      => 'lib/NCBI/Taxonomy.pm', # finds $VERSION
    PREREQ_PM         => {
	DateTime::Format::Natural => 0.96,
	version => 0.77,
	Log::Log4perl => 1.29,
    }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/NCBI/Taxonomy.pm', # retrieve abstract from module
       AUTHOR         => 'Frank Foerster <frank.foerster@biozentrum.uni-wuerzburg.de>') : ()),
);
