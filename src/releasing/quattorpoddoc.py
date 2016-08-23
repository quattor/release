#!/usr/bin/env python2
"""
quattorpoddoc generates markdown documentation from:
 - configuration-modules-core perl documentation
 - CAF perl documentation
 - CCM perl documentation
 - schema pan annotations
 and creates a index for the website on http://quattor.org.

@author: Wouter Depypere (Ghent University)

"""
import sys
import os
import re
from vsc.utils.generaloption import simple_option
from vsc.utils import fancylogger
from vsc.utils.run import run_asyncloop
import tempfile
from lxml import etree
import shutil

MAILREGEX = re.compile(("([a-z0-9!#$%&'*+\/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+\/=?^_`"
                        "{|}~-]+)*(@|\sat\s)(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(\.|"
                        "\sdot\s))+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)"))
PATHREGEX = re.compile(r'(\s+)((?:/[\w{}]+)+\.?\w*)(\s*)')
EXAMPLEMAILS = ["example", "username", "system.admin"]
logger = fancylogger.getLogger()
DOCDIR = "docs"

REPOMAP = {
    "configuration-modules-core": {
        "sitesubdir": "components",
        "target": "/NCM/Component/"
        },
    "configuration-modules-grid":{
        "sitesubdir": "components-grid",
        "target": "/NCM/Component/"
        },
    "CAF": {
        "sitesubdir": "CAF",
        "target": "/CAF/"
        },
    "CCM": {
        "sitesubdir": "CCM",
        "target": "EDG/WP4/CCM/"
        },
    }


def maven_clean_compile(repo_location, repository):
    """
    Executes mvn clean and mvn compile in the given modules_location.
    """
    repoloc = os.path.join(repo_location, repository)
    logger.info("Doing maven clean compile in %s." % repoloc)
    output = run_asyncloop("mvn clean compile", startpath=repoloc)
    logger.debug(output)


def generate_mds(repo, sources, location):
    """
    Takes a list of components with podfiles and generates a md file for it.
    """
    logger.info("Generating md files.")
    mdfiles = []

    comppath = os.path.join(location, DOCDIR, REPOMAP[repo]['sitesubdir'])
    if not os.path.exists(comppath):
        os.makedirs(comppath)

    for source in sources:
        tpl = False
        if source.endswith(".tpl"):
            logger.warning("%s file extension is '.tpl', should become '.pan'." % source)
            tpl = True

        if source.endswith(".pan") or tpl:
            mdfile = create_md_from_pan(source, comppath)
            mdfiles.append(mdfile)
        else:
            sourcename = source.split(REPOMAP[repo]['target'])[-1]
            mdfile = os.path.splitext(sourcename)[0].replace("/", "::").lower() + ".md"

            convert_pod_to_markdown(source, os.path.join(comppath, mdfile))
            mdfiles.append(mdfile)

    logger.info("Written %s md files." % len(mdfiles))
    return mdfiles


def create_md_from_pan(source, comppath):
    """
    Takes a pan schema, creates the pan annotations and parses them to markdown.
    """
    modname = os.path.basename(os.path.split(source)[0])
    mdfile = modname + "::schema.md"
    tmpdir = tempfile.mkdtemp()
    logger.debug("Temporary directory: %s" % tmpdir)
    panccommand = ["panc-annotations", "--output-dir", tmpdir, "--base-dir"]
    panccommand.extend(os.path.split(source))
    output = run_asyncloop(panccommand)
    logger.debug(output)
    namespace = "{http://quattor.org/pan/annotations}"

    tpl = "schema.pan.annotation.xml"
    xml = etree.parse(os.path.join(tmpdir, tpl))
    root = xml.getroot()

    mdtext = []

    mdtext.append("# Types\n")
    for stype in root.findall('%stype' % namespace):
        name = stype.get('name')
        mdtext.append("- /software/%s/%s" % (modname, name))

        for doc in stype.findall(".//%sdesc" % namespace):
            mdtext.append("%s- decription: %s" % (" "*4, doc.text))

        for field in stype.findall(".//%sfield" % namespace):
            mdtext.append("%s- /software/%s/%s/%s" % (" "*4, modname, name, field.get('name')))
            required = field.get('required')
            if required == "true":
                mdtext.append("%s- required" % (" "*8))
            else:
                mdtext.append("%s- optional" % (" "*8))

            for basetype in field.findall(".//%sbasetype" % namespace):
                fieldtype = basetype.get('name')
                mdtext.append("%s- type: %s" % (" "*8, fieldtype))
                if fieldtype == "long" and basetype.get('range'):
                    fieldrange = basetype.get('range')
                    mdtext.append("%s- range: %s" % (" "*8, fieldrange))
            mdtext.append("\n")

    deffunctions = root.findall('%sfunction' % namespace)
    if deffunctions:
        mdtext.append("\n# Functions\n")
        root.findall('%sfunction' % namespace)
        for fnname in deffunctions:
            name = fnname.get('name')
            mdtext.append("- %s" % name)
            for doc in fnname.findall(".//%sdesc" % namespace):
                mdtext.append("   description: %s " % doc.text)
            for arg in fnname.findall(".//%sarg" % namespace):
                mdtext.append("- arg: %s " % arg.text)

    with open(os.path.join(comppath, mdfile), "w") as fih:
        fih.write("\n".join(txt))

    logger.debug("Removing temporary directory: %s" % tmpdir)
    shutil.rmtree(tmpdir)
    return mdfile


def convert_pod_to_markdown(podfile, outputfile):
    """
    Takes a podfile and converts it to a markdown with the help of pod2markdown.
    """
    logger.debug("Running pod2markdown on %s." % podfile)
    output = run_asyncloop("pod2markdown %s" % podfile)
    logger.debug("writing output to %s." % outputfile)
    logger.debug(output)
    with open(outputfile, "w") as fih:
        fih.write(output[1])


def generate_toc(mdfiles, outputloc, indexname):
    """
    Generates a TOC for the parsed components.
    """
    logger.info("Generating TOC as %s." % os.path.join(outputloc, indexname))

    with open(os.path.join(outputloc, indexname), "w") as fih:
        fih.write("site_name: Quattor Documentation\n\n")
        fih.write("theme: 'readthedocs'\n\n")
        fih.write("pages:\n")
        fih.write("- introduction: 'index.md'\n")

        for subdivision in sorted(mdfiles.keys()):
            fih.write("- %s:\n" % subdivision)
            for page in sorted(mdfiles[subdivision]):
                linkname = page.split(".")[0]
                linktopage = "%s/%s" % (subdivision, page)
                write_if_exists(outputloc, linktopage, linkname, fih)
        fih.write("\n")


def write_if_exists(outputloc, linktopage, linkname, fih):
    """
    Checks if the MD exists before adding it to the TOC.
    """
    if os.path.exists(os.path.join(outputloc, DOCDIR, linktopage)):
        logger.debug("Adding %s to toc." % linkname)
        fih.write("    - %s: '%s'\n" % (linkname, linktopage))
    else:
        logger.warn("Expected %s but it does not exist. Not adding to toc."
                    % os.path.join(outputloc, DOCDIR, linktopage))


def remove_mail(mdfiles, outputloc):
    """
    Removes the email addresses from the markdown files.
    """
    logger.info("Removing emailaddresses from md files.")
    counter = 0
    for subdivision in mdfiles.keys():
        for mdfile in mdfiles[subdivision]:
            mdfileloc = os.path.join(outputloc, DOCDIR, subdivision, mdfile)
            with open(mdfileloc, 'r') as fih:
                mdcontent = fih.read()
            replace = False
            for email in re.findall(MAILREGEX, mdcontent):
                logger.debug("Found %s." % email[0])
                replace = True
                if email[0].startswith('//'):
                    replace = False
                for ignoremail in EXAMPLEMAILS:
                    if ignoremail in email[0]:
                        replace = False

            if replace:
                logger.debug("Removed it from line.")
                mdcontent = mdcontent.replace(email[0], '')
                with open(mdfileloc, 'w') as fih:
                    fih.write(mdcontent)
                counter += 1
    logger.info("Removed %s email addresses." % counter)


def remove_whitespace(mdfiles, outputloc):
    """
    Removes extra whitespace (\n\n\n).
    """
    logger.info("Removing extra whitespace from md files.")
    counter = 0
    for subdivision in mdfiles.keys():
        for mdfile in mdfiles[subdivision]:
            mdfileloc = os.path.join(outputloc, DOCDIR, subdivision, mdfile)
            with open(mdfileloc, 'r') as fih:
                mdcontent = fih.read()
            if '\n\n\n' in mdcontent:
                logger.debug("Removing whitespace in %s." % mdfile)
                mdcontent = mdcontent.replace('\n\n\n', '\n')
                with open(mdfileloc, 'w') as fih:
                    fih.write(mdcontent)
                counter += 1
    logger.info("Removed extra whitespace from %s files." % counter)


def decrease_title_size(mdfiles, outputloc):
    """
    Makes titles smaller, e.g. replace "# " with "### ".
    """
    logger.info("Downsizing titles in md files.")
    counter = 0
    for subdivision in mdfiles.keys():
        for mdfile in mdfiles[subdivision]:
            mdfileloc = os.path.join(outputloc, DOCDIR, subdivision, mdfile)
            with open(mdfileloc, 'r') as fih:
                mdcontent = fih.read()
            if '# ' in mdcontent:
                logger.debug("Making titles smaller in %s." % mdfile)
                mdcontent = mdcontent.replace('# ', '### ')
                with open(mdfileloc, 'w') as fih:
                    fih.write(mdcontent)
                counter += 1
    logger.info("Downsized titles in %s files." % counter)


def remove_headers(mdfiles, outputloc):
    """
    Removes MAINTAINER and AUTHOR headers from md files.
    """
    logger.info("Removing AUTHOR and MAINTAINER headers from md files.")
    counter = 0
    for subdivision in mdfiles.keys():
        for mdfile in mdfiles[subdivision]:
            mdfileloc = os.path.join(outputloc, DOCDIR, subdivision, mdfile)
            with open(mdfileloc, 'r') as fih:
                mdcontent = fih.read()
            if '# MAINTAINER' in mdcontent:
                logger.debug("Removing # MAINTAINER in %s." % mdfile)
                mdcontent = mdcontent.replace('# MAINTAINER', '')
                with open(mdfileloc, 'w') as fih:
                    fih.write(mdcontent)
                counter += 1
            if '# AUTHOR' in mdcontent:
                logger.debug("Removing # AUTHOR in %s." % mdfile)
                mdcontent = mdcontent.replace('# AUTHOR', '')
                with open(mdfileloc, 'w') as fih:
                    fih.write(mdcontent)
                counter += 1

    logger.info("Removed %s unused headers." % counter)


def codify_paths(mdfiles, outputloc):
    """
    Puts paths inside code tags
    """
    logger.info("Putting paths inside code tags.")
    counter = 0
    for subdivision in mdfiles.keys():
        for mdfile in mdfiles[subdivision]:
            mdfileloc = os.path.join(outputloc, DOCDIR, subdivision, mdfile)
            with open(mdfileloc, 'r') as fih:
                mdcontent = fih.read()

            logger.debug("Tagging paths in %s." % mdfile)
            mdcontent, counter = PATHREGEX.subn(r'\1`\2`\3', mdcontent)
            with open(mdfileloc, 'w') as fih:
                fih.write(mdcontent)

    logger.info("Code tagged %s paths." % counter)


def check_input_and_commands(sourceloc, outputloc, runmaven):
    """
    Check if the directories are in place.
    Check if the required binaries are in place.
    """
    logger.info("Checking if the given paths exist.")
    if not sourceloc:
        logger.error("Repo location not specified.")
        sys.exit(1)
    if not outputloc:
        logger.error("output location not specified")
        sys.exit(1)
    if not os.path.exists(sourceloc):
        logger.error("Repo location %s does not exist" % sourceloc)
        sys.exit(1)
    for repo in REPOMAP.keys():
        if not os.path.exists(os.path.join(sourceloc, repo)):
            logger.error("Repo location %s does not exist" % os.path.join(sourceloc, repo))
            sys.exit(1)
    if not os.path.exists(outputloc):
        logger.error("Output location %s does not exist" % outputloc)
        sys.exit(1)

    logger.info("Checking if required binaries are installed.")
    if runmaven:
        if not which("mvn"):
            logger.error("The command mvn is not available on this system, please install maven.")
            sys.exit(1)
    if not which("pod2markdown"):
        logger.error("The command pod2markdown is not available on this system, please install pod2markdown.")
        sys.exit(1)


def list_perl_modules(module_location):
    """
    return a list of perl modules in module_location.
    Try to filter out duplicates, pod takes precedence over pm.
    """
    finallist = []
    for path, _, files in os.walk(module_location):
        if not is_wanted_dir(path, files):
            continue

        for mfile in files:
            if is_wanted_file(path, mfile):
                fname = os.path.join(path, mfile)
                duplicate = ""
                if "doc/pod" in fname:
                    duplicate = fname.replace('doc/pod', 'lib/perl')
                    if mfile.endswith('.pod'):
                        duplicate = duplicate.replace(".pod", ".pm")
                    if duplicate in finallist:
                        finallist[finallist.index(duplicate)] = fname
                        continue

                duplicate = ""
                if "lib/perl" in fname:
                    duplicate = fname.replace('lib/perl', 'doc/pod')
                if mfile.endswith('.pm'):
                        duplicate = duplicate.replace(".pm", ".pod")
                    if duplicate not in finallist:
                        finallist.append(fname)
                        continue
                finallist.append(os.path.join(path, mfile))

    return finallist


def is_wanted_dir(path, files):
    """
    Check if the directory matches required criteria:
     - It must be in 'target directory'
     - It should contain files
     - it shoud contain one of the following in the path:
        - doc/pod
        - lib/perl
        - pan
    """
    if 'target' not in path: return False
    if len(files) == 0: return False
    if True not in [substr in path for substr in ["doc/pod", "lib/perl", "pan"]]: return False
    return True


def is_wanted_file(path, filename):
    """
    Check if the file matches one of the criteria:
     - a perl file based on extension
     - schema.pan
     - a perl file based on shebang
    """
    if True in [filename.endswith(ext) for ext in [".pod", ".pm", ".pl"]]: return True
    if filename == "schema.pan": return True
    if len(filename.split(".")) < 2:
        with open(os.path.join(path, filename), 'r') as pfile:
            if 'perl' in pfile.readline(): return True
    return False


def which(command):
    """
    Check if given command is available for the current user on this system.
    """
    found = False
    for direct in os.getenv("PATH").split(':'):
        if os.path.exists(os.path.join(direct, command)):
            found = True

    return found


def main(repoloc, outputloc):
    """
    Main run of the script.
    """
    mdfiles = {}
    for repo in REPOMAP.keys():
        logger.info("Processing %s." % repo)
        if GO.options.maven_compile:
            logger.info("Doing maven clean and compile.")
            maven_clean_compile(repoloc, repo)
        else:
            logger.info("Skipping maven clean and compile.")

        pmodules = list_perl_modules(os.path.join(repoloc, repo))
        mdfiles[REPOMAP[repo]['sitesubdir']] = generate_mds(repo, pmodules, outputloc)

    generate_toc(mdfiles, outputloc, GO.options.index_name)

    if GO.options.remove_emails:
        remove_mail(mdfiles, outputloc)

    if GO.options.remove_headers:
        remove_headers(mdfiles, outputloc)

    if GO.options.small_titles:
        decrease_title_size(mdfiles, outputloc)

    if GO.options.remove_whitespace:
        remove_whitespace(mdfiles, outputloc)

    if GO.options.codify_paths:
        codify_paths(mdfiles, outputloc)


if __name__ == '__main__':
    OPTIONS = {
        'modules_location': ('The location of the repo checkout.', None, 'store', None, 'm'),
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
    logger.info("Starting main.")

    check_input_and_commands(GO.options.modules_location, GO.options.output_location, GO.options.maven_compile)

    main(GO.options.modules_location, GO.options.output_location)

    logger.info("Done.")
