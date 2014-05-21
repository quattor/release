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
from vsc.utils.run import run_asyncloop

LOGGER = fancylogger.getLogger()


def mavencleancompile(modules_location):
    """
    Executes mvn clean and mvn compile in the given modules_location.
    """

    LOGGER.info("Doing maven clean in %s." % modules_location)
    output = run_asyncloop("mvn clean", startpath=modules_location)
    LOGGER.debug(output)

    LOGGER.info("Doing maven compile in %s." % modules_location)
    output = run_asyncloop("mvn compile", startpath=modules_location)
    LOGGER.debug(output)


def convertpodtomarkdown(podfile, outputfile):
    """
    Takes a podfile and converts it to a markdown with the help of pod2markdown.
    """
    LOGGER.debug("Running pod2markdown on %s." % podfile)
    output = run_asyncloop("pod2markdown %s" % podfile)
    LOGGER.debug("writing output to %s." % outputfile)
    fih = open(outputfile)
    fih.write(output)
    fih.close()


def generatetoc(pods, outputloc, indexname):
    """
    Generates a TOC for the parsed components.
    """
    LOGGER.info("Generating TOC as %s." % os.path.join(outputloc, indexname))

    fih = open(os.path.join(outputloc, indexname), "w")

    fih.write("\n\n # COMPONENTS \n\n")

    for component in sorted(pods):
        if len(pods[component]) == 1:
            fih.write(" * %s \n" % component)
        else:
            fih.write(" * %s \n" % component)
            for pod in pods[component]:
                fih.write("    * %s \n" % os.path.splitext(os.path.basename(pod))[0])

    fih.write("\n")
    fih.close()


def removemailadresses():
    """
    Removes the email addresses from the markdown files.
    """
    pass


def checkinputandcommands(modloc, outputloc, runmaven):
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
    if runmaven:
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
    counter = 0
    LOGGER.info("Searching for components in %s." % module_location)
    for posloc in os.listdir(module_location):
        if os.path.isdir(os.path.join(module_location, posloc)) and posloc.startswith("ncm-"):
            components.append(posloc)
            LOGGER.debug("Adding %s to component list." % posloc)
            counter += 1
    LOGGER.info("Found %s components." % counter)
    return components


def listpods(module_location, components):
    """
    return an array of the pod files per component.
    """
    comppods = {}
    counter = 0
    LOGGER.info("searching for podfiles per component.")
    for comp in components:
        pods = []

        for root, dirs, files in os.walk(os.path.join(module_location, comp, "target")):
            for fileh in files:

                if fileh.endswith(".pod"):
                    LOGGER.debug("%s - %s - %s" % (comp, fileh, root))
                    counter += 1
                    pods.append(os.path.join(root, fileh))

        comppods[comp] = pods
    LOGGER.info("Found %s pod files." % counter)
    LOGGER.debug(comppods)
    return comppods


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
                          'store_true', False, 'c'),
        'index_name': ('Filename for the index/toc for the components', None, 'store', 'components.md', 'i')
    }
    GO = simple_option(OPTIONS)
    LOGGER.info("Starting main.")

    checkinputandcommands(GO.options.modules_location, GO.options.output_location, GO.options.maven_compile)

    if GO.options.maven_compile:
        LOGGER.info("Doing maven clean and compile.")
        mavencleancompile(GO.options.modules_location)
    else:
        LOGGER.info("Skipping maven clean and compile.")

    COMPS = listcomponents(GO.options.modules_location)
    PODS = listpods(GO.options.modules_location, COMPS)

    generatetoc(PODS, GO.options.output_location, GO.options.index_name)
