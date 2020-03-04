"""Hold all classes intended for settings."""

import os
from vsc.utils import fancylogger
logger = fancylogger.getLogger()

class Repo(object):
    """Repo has all settings needed to build a repository."""

    def __init__(self, name, path):
        """Initialize basic configuration of a repository."""
        # name of the repository
        self.name = name
        # file path to the repository
        self.path = path
        # file paths that will be searched for files
        self.sourcepaths = []
        # should maven compile be run
        self.mvncompile = True
        # should an attempt be made to remove email addresses from content
        self.remove_emails = True
        # section header for the website
        self.sitesection = None
        # subdirectories to use instead of self.path, used to build self.basepaths
        self.subdirs = []
        # directories to be retained (substring, e.g. /doc/pod/, /lib/perl)
        self.wanted_dirs = None
        # extensions of files to use (['.pod', '.pm', '.pl', '.pan'])
        self.wanted_extensions = None
        # make an attempt to put code tags around paths
        self.codify_paths = True
        # make an attempt to replace code tags by cleaner code tags
        self.clean_code_tags = True
        # a prefix for titles
        self.title_prefix = None
        # a prefix for titles only applied to pan files
        self.title_pan_prefix = None
        # Prefix pan path in a schema
        self.pan_path_prefix = None
        # Guess a basename for pan path (e.g. ncm-metaconfig and such)
        self.pan_guess_basename = False
        # a list of regex's to remove from title
        self.title_remove = []
        # a list of source pages
        self.sources = []
        # a list of files to move [source, destination, ignore_patterns]
        self.movefiles = []

        self.configure()
        self.create_paths()


    def __str__(self):
        """Representation of class."""
        sbl = []
        for key in self.__dict__:
            sbl.append("{key}='{value}'".format(key=key, value=self.__dict__[key]))

        return ', '.join(sbl)

    def __repr__(self):
        """Representation of class."""
        return self.__str__()

    def check(self):
        """Check configuration if it will actually work."""
        returnvalue = True
        if not self.name:
            logger.warning("No name set.")
            returnvalue = False
        if not self.path:
            logger.warning("No path set for %s.", self.name)
            returnvalue = False
        if not self.sitesection:
            logger.warning("No sitesection set for %s.", self.name)
            returnvalue = False
        if not self.sourcepaths:
            logger.warning("No source paths set for %s.", self.name)
            returnvalue = False
        if not self.wanted_dirs:
            logger.warning("No wanted directories set for %s.", self.name)
            returnvalue = False
        if not self.wanted_extensions:
            logger.warning("No wanted extensions set for %s.", self.name)
            returnvalue = False

        return returnvalue

    def create_paths(self):
        """Create paths to use based on subdir settings."""
        logger.debug("building paths.")
        if self.subdirs:
            for subdir in self.subdirs:
                logger.debug("Subdirectory: %s", subdir)
                self.sourcepaths.append(os.path.join(self.path, subdir))
        else:
            logger.debug("No subdirectories. Using %s.", self.path)
            self.sourcepaths.append(self.path)

        logger.debug('Sourcepaths: %s', self.sourcepaths)

    def configure(self):
        """Choose configuration settings based on self.name."""
        if self.name == 'ncm-ncd':
            self.configure_ncm_ncd()

        if self.name == 'maven-tools':
            self.configure_maven_tools()

        if self.name == 'CAF':
            self.configure_caf()

        if self.name == 'CCM':
            self.configure_ccm()

        if self.name == 'configuration-modules-grid':
            self.configure_components_grid()

        if self.name == 'configuration-modules-core':
            self.configure_components()

        if self.name == 'template-library-core':
            self.configure_template_library_core()


    def configure_ncm_ncd(self):
        """Set attributes for ncm-ncd."""
        self.sitesection = 'ncm-ncd'
        self.wanted_dirs = ['target/doc/pod']
        self.wanted_extensions = ['.pod', ]

    def configure_maven_tools(self):
        """Set attributes for maven-tools."""
        self.sitesection = 'Unittesting'
        self.subdirs = ['package-build-scripts',]
        self.wanted_dirs = ['target/doc/pod/Test', 'target/lib/perl/Test']
        self.wanted_extensions = ['.pod', '.pm', '.pl']

    def configure_caf(self):
        """Set attributes for CAF."""
        self.sitesection = 'CAF'
        self.wanted_dirs = ['target/doc/pod', 'target/lib/perl']
        self.wanted_extensions = ['.pod', '.pm']

    def configure_ccm(self):
        """Set attributes for CCM."""
        self.sitesection = 'CCM'
        self.wanted_dirs = ['target/lib/perl/EDG/WP4/CCM', 'target/doc/pod/EDG/WP4/CCM']
        self.wanted_extensions = ['.pod', '.pm']
        self.title_prefix = '/EDG/WP4/CCM/'

    def configure_components_grid(self):
        """Set attributes for configuration-modules-grid."""
        self.sitesection = 'components-grid'
        self.wanted_dirs = ['target/doc/pod', 'target/lib/perl', 'target/pan/components/']
        self.wanted_extensions = ['.pod', '.pm', '.pl', '.pan']
        self.title_remove = [r'ncm\-\w*']
        self.title_pan_prefix = '/NCM/Component/'
        self.pan_path_prefix = '/software/components/'
        self.pan_guess_basename = True

    def configure_components(self):
        """Set attributes for configuration-modules-core."""
        self.sitesection = 'components'
        self.wanted_dirs = ['target/doc/pod', 'target/lib/perl', 'target/pan/components/',
                            'target/pan/metaconfig/']
        self.wanted_extensions = ['.pod', '.pm', '.pl', '.pan']
        self.title_remove = [r'ncm\-\w*']
        self.title_pan_prefix = '/NCM/Component/'
        self.pan_path_prefix = '/software/components/'
        self.pan_guess_basename = True
        self.movefiles.append(
            ['ncm-metaconfig/src/main/metaconfig/',
             'ncm-metaconfig/target/pan/metaconfig/metaconfig',
             ['*.tt', '*tests*']
            ])

    def configure_template_library_core(self):
        """Set attributes for template-library-core."""
        self.mvncompile = False
        self.sitesection = 'template-library-core'
        self.subdirs = ['pan', 'quattor']
        self.wanted_dirs = ['',]
        self.wanted_extensions = ['.pan',]

class Sourcepage(object):
    """Sourcepage has all attributes to correctly build a rst page."""

    def __init__(self, title, path, pan_path_prefix, pan_guess_basename):
        """Initialize basic configuration of a source page."""
        self.path = path
        self.title = title
        self.pan_path_prefix = pan_path_prefix
        self.pan_guess_basename = pan_guess_basename
        self.rstcontent = None
        filetype = os.path.splitext(path)[1].lstrip('.')
        if filetype in ['pm', 'pl', 'pod']:
            filetype = 'perl'

    def __str__(self):
        """Representation of class."""
        sbl = []
        for key in self.__dict__:
            sbl.append("{key}='{value}'".format(key=key, value=self.__dict__[key]))

        return '{%s}' % ', '.join(sbl)

    def __repr__(self):
        """Representation of class."""
        return self.__str__()
