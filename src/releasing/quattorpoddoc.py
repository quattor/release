#!/usr/bin/env python2
"""
quattor-pod-doc generates markdown documentation from the
pod's in configuration-modules-core and creates a index for
the website on http://quattor.org.

@author: Wouter Depypere (Ghent University)

"""
import sys
import os
import re
from vsc.utils.generaloption import simple_option
from vsc.utils import fancylogger
from vsc.utils.run import run_asyncloop

MAILREGEX = re.compile(("([a-z0-9!#$%&'*+\/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+\/=?^_`"
                        "{|}~-]+)*(@|\sat\s)(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(\.|"
                        "\sdot\s))+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)"))
PATHREGEX = re.compile(r'(\s+)((?:/[\w{}]+)+\.?\w*)(\s*)')
EXAMPLEMAILS = ["example", "username", "system.admin"]
LOGGER = fancylogger.getLogger()
SUBDIR = "components"
DOCDIR = "docs"


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


def generatemds(pods, location):
    """
    Takes a list of components with podfiles and generates a md file for it.
    """
    LOGGER.info("Generating md files.")
    counter = 0
    mdfiles = []

    comppath = os.path.join(location, DOCDIR, SUBDIR)
    if not os.path.exists(comppath):
        os.makedirs(comppath)

    for component in sorted(pods):
        for pod in pods[component]:
            component = component.replace('ncm-', '')
            title = os.path.splitext(os.path.basename(pod))[0]
            if component != title:
                title = component+'::'+title
            mdfile = os.path.join(comppath, '%s.md' % title)
            convertpodtomarkdown(pod, mdfile)
            counter += 1
            mdfiles.append(mdfile)

    LOGGER.info("Written %s md files." % counter)
    return mdfiles


def convertpodtomarkdown(podfile, outputfile):
    """
    Takes a podfile and converts it to a markdown with the help of pod2markdown.
    """
    LOGGER.debug("Running pod2markdown on %s." % podfile)
    output = run_asyncloop("pod2markdown %s" % podfile)
    LOGGER.debug("writing output to %s." % outputfile)
    LOGGER.debug(output)
    with open(outputfile, "w") as fih:
        fih.write(output[1])


def addintrogreeter(outputloc):
    """
    Writes small intro file.
    """
    LOGGER.info("Adding introduction page.")
    with open(os.path.join(outputloc, DOCDIR, "index.md"), "w") as fih:
        fih.write("This is the documentation for the core set of configuration modules for configuring systems with Quattor.\n")


def generatetoc(pods, outputloc, indexname):
    """
    Generates a TOC for the parsed components.
    """
    LOGGER.info("Generating TOC as %s." % os.path.join(outputloc, indexname))

    with open(os.path.join(outputloc, indexname), "w") as fih:
        fih.write("site_name: Quattor Configuration Modules (Core)\n\n")
        fih.write("theme: 'readthedocs'\n\n")
        fih.write("pages:\n")
        fih.write("- Home: 'index.md'\n")

        addintrogreeter(outputloc)

        fih.write("- Components:\n")
        for component in sorted(pods):
            name = component.replace('ncm-', '')
            linkname = "%s/%s.md" % (SUBDIR, name)
            fih.write("    - '%s'\n" % linkname)
            if len(pods[component]) > 1:
                for pod in sorted(pods[component][1:]):
                    subname = os.path.splitext(os.path.basename(pod))[0]
                    linkname = "%s/%s::%s.md" % (SUBDIR, name, subname)
                    fih.write("    - '%s'\n" % linkname)


def removemailadresses(mdfiles):
    """
    Removes the email addresses from the markdown files.
    """
    LOGGER.info("Removing emailaddresses from md files.")
    counter = 0
    for mdfile in mdfiles:
        with open(mdfile, 'r') as fih:
            mdcontent = fih.read()
        for email in re.findall(MAILREGEX, mdcontent):
            LOGGER.debug("Found %s." % email[0])
            replace = True
            if email[0].startswith('//'):
                replace = False
            for ignoremail in EXAMPLEMAILS:
                if ignoremail in email[0]:
                    replace = False

            if replace:
                LOGGER.debug("Removed it from line.")
                mdcontent = mdcontent.replace(email[0], '')
                with open(mdfile, 'w') as fih:
                    fih.write(mdcontent)
                counter += 1
    LOGGER.info("Removed %s email addresses." % counter)


def removewhitespace(mdfiles):
    """
    Removes extra whitespace (\n\n\n).
    """
    LOGGER.info("Removing extra whitespace from md files.")
    counter = 0
    for mdfile in mdfiles:
        with open(mdfile, 'r') as fih:
            mdcontent = fih.read()
        if '\n\n\n' in mdcontent:
            LOGGER.debug("Removing whitespace in %s." % mdfile)
            mdcontent = mdcontent.replace('\n\n\n', '\n')
            with open(mdfile, 'w') as fih:
                fih.write(mdcontent)
            counter += 1
    LOGGER.info("Removed extra whitespace from %s files." % counter)


def decreasetitlesize(mdfiles):
    """
    Makes titles smaller, e.g. replace "# " with "### ".
    """
    LOGGER.info("Downsizing titles in md files.")
    counter = 0
    for mdfile in mdfiles:
        with open(mdfile, 'r') as fih:
            mdcontent = fih.read()
        if '# ' in mdcontent:
            LOGGER.debug("Making titles smaller in %s." % mdfile)
            mdcontent = mdcontent.replace('# ', '### ')
            with open(mdfile, 'w') as fih:
                fih.write(mdcontent)
            counter += 1
    LOGGER.info("Downsized titles in %s files." % counter)


def removeheaders(mdfiles):
    """
    Removes MAINTAINER and AUTHOR headers from md files.
    """
    LOGGER.info("Removing AUTHOR and MAINTAINER headers from md files.")
    counter = 0
    for mdfile in mdfiles:
        with open(mdfile, 'r') as fih:
            mdcontent = fih.read()
        if '# MAINTAINER' in mdcontent:
            LOGGER.debug("Removing # MAINTAINER in %s." % mdfile)
            mdcontent = mdcontent.replace('# MAINTAINER', '')
            with open(mdfile, 'w') as fih:
                fih.write(mdcontent)
            counter += 1
        if '# AUTHOR' in mdcontent:
            LOGGER.debug("Removing # AUTHOR in %s." % mdfile)
            mdcontent = mdcontent.replace('# AUTHOR', '')
            with open(mdfile, 'w') as fih:
                fih.write(mdcontent)
            counter += 1

    LOGGER.info("Removed %s unused headers." % counter)


def codifypaths(mdfiles):
    """
    Puts paths inside code tags
    """
    LOGGER.info("Putting paths inside code tags.")
    counter = 0
    for mdfile in mdfiles:
        with open(mdfile, 'r') as fih:
            mdcontent = fih.read()

        LOGGER.debug("Tagging paths in %s." % mdfile)
        mdcontent, counter = PATHREGEX.subn(r'\1`\2`\3', mdcontent)
        with open(mdfile, 'w') as fih:
            fih.write(mdcontent)

    LOGGER.info("Code tagged %s paths." % counter)


def checkinputandcommands(modloc, outputloc, runmaven):
    """
    Check if the directories are in place.
    Check if the required binaries are in place.
    """
    LOGGER.info("Checking if the given paths exist.")
    if not modloc:
        LOGGER.error("configuration-modules-core location not specified")
        sys.exit(1)
    if not outputloc:
        LOGGER.error("output location not specified")
        sys.exit(1)
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

        for root, _, files in os.walk(os.path.join(module_location, comp, "target")):
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
        if os.path.exists(os.path.join(direct, command)):
            found = True

    return found


if __name__ == '__main__':
    OPTIONS = {
        'modules_location': ('The location of the configuration-modules-core checkout.', None, 'store', None, 'm'),
        'output_location': ('The location where the output markdown files should be written to.', None, 'store', None, 'o'),
        'maven_compile': ('Execute a maven clean and maven compile before generating the documentation.', None, 'store_true', False, 'c'),
        'index_name': ('Filename for the index/toc for the components.', None, 'store', 'mkdocs.yml', 'i'),
        'remove_emails': ('Remove email addresses from generated md files.', None, 'store_true', True, 'r'),
        'remove_whitespace': ('Remove whitespace (\n\n\n) from md files.', None, 'store_true', True, 'w'),
        'remove_headers': ('Remove unneeded headers from files (MAINTAINER and AUTHOR).', None, 'store_true', True, 'R'),
        'small_titles': ('Decrease the title size in the md files.', None, 'store_true', True, 's'),
        'codify_paths': ('Put paths inside code tags.', None, 'store_true', True, 'p'),
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

    MDS = generatemds(PODS, GO.options.output_location)
    generatetoc(PODS, GO.options.output_location, GO.options.index_name)

    if GO.options.remove_emails:
        removemailadresses(MDS)

    if GO.options.remove_headers:
        removeheaders(MDS)

    if GO.options.small_titles:
        decreasetitlesize(MDS)

    if GO.options.remove_whitespace:
        removewhitespace(MDS)

    if GO.options.codify_paths:
        codifypaths(MDS)

    LOGGER.info("Done.")
