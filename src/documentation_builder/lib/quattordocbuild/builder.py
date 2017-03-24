"""Build documentation from quattor sources."""

import os
import sys
import re
from sourcehandler import get_source_files
from rsthandler import generate_rst, cleanup_content
from config import build_repository_map
from vsc.utils import fancylogger

logger = fancylogger.getLogger()


def build_documentation(repository_location, cleanup_options, compile, output_location):
    """Build the whole documentation from quattor repositories."""
    if not check_input(repository_location, output_location):
        sys.exit(1)
    if not check_commands(compile):
        sys.exit(1)
    repository_map = build_repository_map(repository_location)
    if not repository_map:
        sys.exit(1)

    rstlist = {}

    for repository in repository_map.keys():
        logger.info("Building documentation for %s." % repository)
        fullpath = os.path.join(repository_location, repository)
        if repository_map[repository]["subdir"]:
            fullpath = os.path.join(fullpath, repository_map[repository]["subdir"])
        logger.info("Path: %s." % fullpath)
        sources = get_source_files(fullpath, compile)
        logger.debug("Sources:" % sources)
        sources = make_titles(sources, repository_map[repository]['targets'])
        rst = generate_rst(sources)
        cleanup_content(rst, cleanup_options)
        rstlist[repository] = rst

    site_pages = build_site_structure(rstlist, repository_map)
    # site_pages = make_interlinks(site_pages) # disabled for now
    write_site(site_pages, output_location, "docs")
    return True


def which(command):
    """Check if given command is available for the current user on this system."""
    found = False
    for direct in os.getenv("PATH").split(':'):
        if os.path.exists(os.path.join(direct, command)):
            found = True

    return found


def check_input(sourceloc, outputloc):
    """Check input and locations."""
    logger.info("Checking if the given paths exist.")
    if not sourceloc:
        logger.error("Repo location not specified.")
        return False
    if not outputloc:
        logger.error("output location not specified")
        return False
    if not os.path.exists(sourceloc):
        logger.error("Repo location %s does not exist" % sourceloc)
        return False
    if not os.path.exists(outputloc):
        logger.error("Output location %s does not exist" % outputloc)
        return False
    if not os.listdir(outputloc) == []:
        logger.error("Output location %s is not empty." % outputloc)
        return False
    return True


def check_commands(runmaven):
    """Check required binaries."""
    if runmaven:
        if not which("mvn"):
            logger.error("The command mvn is not available on this system, please install maven.")
            return False
    if not which("pod2rst"):
        logger.error("The command pod2rst is not available on this system, please install pod2rst.")
        return False
    return True


def make_titles(sources, targets):
    """Add titles to sources."""
    new_sources = {}
    for source in sources:
        title = make_title_from_source_path(source, targets)
        new_sources[title] = source

    return new_sources


def make_title_from_source_path(source, targets):
    """Make a title from source path."""
    found = False
    for target in targets:
        if target in source and not found:
            title = source.split(target)[-1]
            title = os.path.splitext(title)[0].replace("/", " :: ")
            return title
        if not found:
            logger.error("No suitable target found for %s in %s." % (source, targets))

    return False


def build_site_structure(rstlist, repository_map):
    """Make a mapping of files with their new names for the website."""
    sitepages = {}
    for repo, rsts in rstlist.iteritems():
        sitesection = repository_map[repo]['sitesection']

        sitepages[sitesection] = {}

        targets = repository_map[repo]['targets']
        for source, rst in rsts.iteritems():
            found = False
            for target in targets:
                if target in source and not found:
                    newname = source.split(target)[-1]
                    newname = os.path.splitext(newname)[0].replace("/", "_") + ".rst"
                    sitepages[sitesection][newname] = rst
                    found = True
            if not found:
                logger.error("No suitable target found for %s in %s." % (source, targets))

    logger.debug("sitepages: %s" % sitepages)
    return sitepages


def make_interlinks(pages):
    """Make links in the content based on pagenames."""
    logger.info("Creating interlinks.")
    newpages = pages
    for subdir in pages:
        for page in pages[subdir]:
            basename = os.path.splitext(page)[0]
            link = '../%s/%s' % (subdir, page)
            regxs = []
            regxs.append("`%s`" % basename)
            regxs.append("`%s::%s`" % (subdir, basename))

            cpans = "https://metacpan.org/pod/"

            if subdir == 'CCM':
                regxs.append("\[{2}::{0}\]\({1}{2}::{0}\)".format(basename, cpans, "EDG::WP4::CCM"))
            if subdir == 'Unittest':
                regxs.append("\[{2}::{0}\]\({1}{2}::{0}\)".format(basename, cpans, "Test"))
            if subdir in ['components', 'components-grid']:
                regxs.append("\[{2}::{0}\]\({1}{2}::{0}\)".format(basename, cpans, "NCM::Component"))
                regxs.append("`ncm-%s`" % basename)
                regxs.append("ncm-%s" % basename)

            for regex in regxs:
                newpages = replace_regex_link(newpages, regex, basename, link)

    return newpages


def replace_regex_link(pages, regex, basename, link):
    """Replace links in a bunch of pages based on a regex."""
    regex = r'( |^|\n)%s([,. $])' % regex
    for subdir in pages:
        for page in pages[subdir]:
            content = pages[subdir][page]
            if (basename not in page or basename == "Quattor") and basename in content:
                content = re.sub(regex, "\g<1>[%s](%s)\g<2>" % (basename, link), content)
                pages[subdir][page] = content
    return pages


def write_site(sitepages, location, docsdir):
    """Write the pages for the website to disk."""
    for subdir, pages in sitepages.iteritems():
        fullsubdir = os.path.join(location, docsdir, subdir)
        if not os.path.exists(fullsubdir):
            os.makedirs(fullsubdir)
        for pagename, content in pages.iteritems():
            with open(os.path.join(fullsubdir, pagename), 'w') as fih:
                fih.write(content)
