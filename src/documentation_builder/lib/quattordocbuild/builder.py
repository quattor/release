"""Build documentation from quattor sources."""

import os
import sys
from template import Template, TemplateException
from sourcehandler import get_source_files
from markdownhandler import generate_markdown, cleanup_content
from vsc.utils import fancylogger

logger = fancylogger.getLogger()


def check_repository_map(repository_map):
    """Check if a repository mapping is valid."""
    logger.info("Checking repository map.")
    if repository_map is None:
        logger.error("Repository map is None.")
        return False
    if len(repository_map) == 0:
        logger.error("Repository map is an empty list.")
        return False
    for repository in repository_map.keys():
        keys = repository_map[repository].keys()
        for opt in ['targets', 'sitesubdir']:
            if opt not in keys:
                logger.error("Respository %s does not have a '%s' in repository_map." % (repository, opt))
                return False
        if type(repository_map[repository]['targets']) is not list:
            logger.error("Repository %s targets is not a list." % repository)
            return False
    return True


def build_documentation(repository_location, repository_map, cleanup_options, compile, output_location):
    """Build the whole documentation from quattor repositories."""
    if not check_repository_map(repository_map):
        sys.exit(1)
    if not check_input(repository_map, repository_location, output_location):
        sys.exit(1)
    if not check_commands(compile):
        sys.exit(1)

    markdownlist = {}

    for repository in repository_map.keys():
        logger.info("Building documentation for %s." % repository)
        fullpath = os.path.join(repository_location, repository)
        logger.info("Path: %s." % fullpath)
        sources = get_source_files(fullpath, compile)
        logger.debug("Sources:" % sources)
        markdown = generate_markdown(sources)
        cleanup_content(markdown, cleanup_options)
        markdownlist[repository] = markdown

    site_pages = build_site_structure(markdownlist, repository_map)
    write_site(site_pages, output_location, "docs")
    return True


def which(command):
    """Check if given command is available for the current user on this system."""
    found = False
    for direct in os.getenv("PATH").split(':'):
        if os.path.exists(os.path.join(direct, command)):
            found = True

    return found


def check_input(repository_map, sourceloc, outputloc):
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
    for repo in repository_map.keys():
        if not os.path.exists(os.path.join(sourceloc, repo)):
            logger.error("Repo location %s does not exist" % os.path.join(sourceloc, repo))
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
    if not which("pod2markdown"):
        logger.error("The command pod2markdown is not available on this system, please install pod2markdown.")
        return False
    return True


def build_site_structure(markdownlist, repository_map):
    """Make a mapping of files with their new names for the website."""
    sitepages = {}
    for repo, markdowns in markdownlist.iteritems():
        sitesubdir = repository_map[repo]['sitesubdir']

        sitepages[sitesubdir] = {}

        targets = repository_map[repo]['targets']
        for source, markdown in markdowns.iteritems():
            found = False
            for target in targets:
                if target in source and not found:
                    newname = source.split(target)[-1]
                    newname = os.path.splitext(newname)[0].replace("/", "::") + ".md"
                    sitepages[sitesubdir][newname] = markdown
                    found = True
            if not found:
                logger.error("No suitable target found for %s in %s." % (source, targets))
    return sitepages


def write_site(sitepages, location, docsdir):
    """Write the pages for the website to disk and build a toc."""
    toc = {}
    for subdir, pages in sitepages.iteritems():
        toc[subdir] = set()
        fullsubdir = os.path.join(location, docsdir, subdir)
        if not os.path.exists(fullsubdir):
            os.makedirs(fullsubdir)
        for pagename, content in pages.iteritems():
            with open(os.path.join(fullsubdir, pagename), 'w') as fih:
                fih.write(content)

            toc[subdir].add(pagename)

        # Sort the toc, ignore theccase.
        toc[subdir] = sorted(toc[subdir], key=lambda s: s.lower())

    write_toc(toc, location)


def write_toc(toc, location):
    """Write the toc to disk."""
    try:
        name = 'toc.tt'
        template = Template({'INCLUDE_PATH': os.path.join(os.path.dirname(__file__), 'tt')})
        tocfile = template.process(name, {'toc': toc})
    except TemplateException as e:
        msg = "Failed to render template %s with data %s: %s." % (name, toc, e)
        logger.error(msg)
        raise TemplateException('render', msg)

    with open(os.path.join(location, "mkdocs.yml"), 'w') as fih:
        fih.write(tocfile)
