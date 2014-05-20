"""
quattor-pod-doc generates markdown documentation from the
pod's in configuration-modules-core and creates a index for
the website on http://quattor.org.

@author: Wouter Depypere (Ghent University)

"""

from vsc.utils.generaloption import simple_option
from vsc.utils import fancylogger
from vsc.utils.run import run_simple

LOGGER = fancylogger.getLogger()


def mavencleancompile(modules_location):
    """
    Executes mvn clean and mvn compile in the given modules_location.
    """

    LOGGER.info("Doing maven clean in %s." % modules_location)
    output = run_simple("mvn clean", startpath=modules_location)
    LOGGER.debug(output)

    LOGGER.info("Doing maven compile in %s." % modules_location)
    output = run_simple("mvn compile", startpath=modules_location)
    LOGGER.debug(output)


def convertpodtomarkdown(podfile, outputfile):
    """
    Takes a podfile and converts it to a markdown with the help of pod2markdown.
    """
    pass


def generatetoc():
    """
    Generates a TOC for the parsed components.
    """
    pass


def removemailadresses():
    """
    Removes the email addresses from the markdown files.
    """
    pass

if __name__ == '__main__':
    OPTIONS = {
        'modules_location': ('The location of the configuration-modules-core checkout.', None, 'store',
                             '/home/wdpypere/workspace/configuration-modules-core', 'm'),
        'maven_compile': ('Execute a maven clean and maven compile before generating the documentation.', None,
                          'store_true', False, 'c')
    }
    GO = simple_option(OPTIONS)
    LOGGER.info("Starting main.")

    if GO.options.maven_compile:
        LOGGER.info("Doing maven clean and compile.")
        mavencleancompile(GO.options.modules_location)
    else:
        LOGGER.info("Skipping maven clean and compile.")
