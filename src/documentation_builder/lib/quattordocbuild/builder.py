"""Build documentation from quattor sources."""

import os
import sys
import re
import codecs
from multiprocessing import Pool
from vsc.utils import fancylogger
from sourcehandler import get_source_files
from rsthandler import generate_rst_from_repository
from config import build_repository_map

logger = fancylogger.getLogger()
RESULTS = []

def build_documentation(repository_location, output_location, singlet=False):
    """Build the whole documentation from quattor repositories."""
    if not check_input(repository_location, output_location):
        sys.exit(1)
    if not check_commands():
        sys.exit(1)
    repository_map = build_repository_map(repository_location)
    if not repository_map:
        sys.exit(1)

    if singlet:
        for repository in repository_map:
            repository = build_docs(repository)
            RESULTS.append(repository)
    else:
        pool = Pool()
        for repository in repository_map:
            logger.debug("Starting worker for %s.", repository.name)
            pool.apply_async(build_docs, args=(repository, ), callback=log_result)
        pool.close()
        pool.join()

    site_pages = build_site_structure(RESULTS)
    # site_pages = make_interlinks(site_pages) # disabled for now
    write_site(site_pages, output_location, "docs")
    return True

def log_result(repository):
    """Catch results given by subprocesses."""
    logger.info('Received %s from worker.', repository.name)
    RESULTS.append(repository)

def build_docs(repository):
    logger.info("Building documentation for %s.", repository.name)
    logger.debug(repository)
    repository = get_source_files(repository)
    logger.debug("Repository: %s", repository)
    repository = generate_rst_from_repository(repository)
    return repository

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
        logger.error("Repo location %s does not exist", sourceloc)
        return False
    if not os.path.exists(outputloc):
        logger.error("Output location %s does not exist", outputloc)
        return False
    if not os.listdir(outputloc) == []:
        logger.error("Output location %s is not empty.", outputloc)
        return False
    return True


def check_commands():
    """Check required binaries."""
    if not which("mvn"):
        logger.error("The command mvn is not available on this system, please install maven.")
        return False
    if not which("pod2rst"):
        logger.error("The command pod2rst is not available on this system, please install pod2rst.")
        return False
    return True


def build_site_structure(repository_map):
    """Make a mapping of files with their new names for the website."""
    sitepages = {}
    for repo in repository_map:
        sitepages[repo.sitesection] = {}
        for sourcepage in repo.sources:
            filename = '%s.rst' % sourcepage.title
            filename = filename.replace('\::', '_')
            filename = filename.replace(' - ', '_')
            logger.debug("filename will be: %s", filename)
            sitepages[repo.sitesection][filename] = sourcepage.rstcontent

    logger.debug("sitepages: %s", sitepages)
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
                regxs.append(r"\[{2}::{0}\]\({1}{2}::{0}\)".format(basename, cpans, "EDG::WP4::CCM"))
            if subdir == 'Unittest':
                regxs.append(r"\[{2}::{0}\]\({1}{2}::{0}\)".format(basename, cpans, "Test"))
            if subdir in ['components', 'components-grid']:
                regxs.append(r"\[{2}::{0}\]\({1}{2}::{0}\)".format(basename, cpans, "NCM::Component"))
                regxs.append(r"`ncm-%s`" % basename)
                regxs.append(r"ncm-%s" % basename)

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
                content = re.sub(regex, r"\g<1>[%s](%s)\g<2>" % (basename, link), content)
                pages[subdir][page] = content
    return pages


def write_site(sitepages, location, docsdir):
    """Write the pages for the website to disk."""
    for subdir, pages in sitepages.iteritems():
        fullsubdir = os.path.join(location, docsdir, subdir)
        if not os.path.exists(fullsubdir):
            os.makedirs(fullsubdir)
        for pagename, content in pages.iteritems():
            with codecs.open(os.path.join(fullsubdir, pagename), 'w', encoding='utf-8') as fih:
                fih.write(content)
