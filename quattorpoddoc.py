"""
quattor-pod-doc generates markdown documentation from the
pod's in configuration-modules-core and creates a index for
the website on http://quattor.org.

@author: Wouter Depypere (Ghent University)

"""
import sys
import os
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


def checkinputandcommands(modloc, outputloc):
    """
    Check if the directories are in place.
    Check if the required binaries are in place.
    """
    LOGGER.info("Checking if the given paths exist.")
    if not os.path.exists(modloc):
        LOGGER.error("configuration-modules-core location %s does not exist" % modloc)
        sys.exit(1)
    if not os.path.exists(outputloc):
        LOGGER.error("Output location %s does not exist" % outputloc)
        sys.exit(1)

    LOGGER.info("Checking if required binaries are installed.")
    if not which("mvn"):
        LOGGER.error("The command mvn is not available on this system, please install maven.")
        sys.exit(1)
    if not which("pod2markdown"):
        LOGGER.error("The command pod2markdown is not available on this system, please install pod2markdown.")
        sys.exit(1)


def listcomponents(module_location):
    """
    return a list of components in module_location.
    """
    components = []
    LOGGER.info("Searching for components in %s." % module_location)
    for posloc in os.listdir(module_location):
        if os.path.isdir(os.path.join(module_location, posloc)) and posloc.startswith("ncm-"):
            components.append(posloc)
            LOGGER.debug("Adding %s to component list." % posloc)
    return components
    
    
def which(command):
    """
    Check if given command is available for the current user on this system.
    """
    found = False
    for direct in os.getenv("PATH").split(':'):
        if (os.path.exists(os.path.join(direct, command))):
            found = True

    return found


if __name__ == '__main__':
    OPTIONS = {
        'modules_location': ('The location of the configuration-modules-core checkout.', None, 'store',
                             '/home/wdpypere/workspace/configuration-modules-core', 'm'),
        'output_location': ('The location where the output markdown files should be written to.', None, 'store',
                            '/home/wdpypere/quattor-component-docs', 'o'),
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
    checkinputandcommands(GO.options.modules_location, GO.options.output_location)

    listcomponents(GO.options.modules_location)
    
