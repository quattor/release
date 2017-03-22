"""Module to handle markdown operations."""

import re

from vsc.utils import fancylogger
from vsc.utils.run import run_asyncloop
from panhandler import rst_from_pan

logger = fancylogger.getLogger()

MAILREGEX = re.compile(("([a-zA-Z0-9!#$%&'*+\/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+\/=?^_`"
                        "{|}~-]+)*(@|\sat\s)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(\.|"
                        "\sdot\s))+[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)"))
PATHREGEX = re.compile(r'(\s+)((?:/[\w{}]+)+\.?\w*)(\s*)')
EXAMPLEMAILS = ["example", "username", "system.admin"]


def generate_markdown(sources):
    """Generate markdown."""
    logger.info("Generating md files.")

    markdownlist = {}

    for source in sources:
        logger.debug("Parsing %s." % source)
        if source.endswith(".pan"):
            markdown = rst_from_pan(source)
            if markdown is not None:
                markdownlist[source] = markdown
        else:
            markdown = rst_from_perl(source)
            if markdown is not None:
                markdownlist[source] = markdown

    return markdownlist


def rst_from_perl(podfile):
    """
    Take a perl file and converts it to a reStrcturedText with the help of pod2rst.

    Returns True if pod2rst worked, False if it failed.
    """
    logger.info("Making markdown from perl: %s." % podfile)
    ec, output = run_asyncloop("pod2rst --infile %s" % podfile)
    logger.debug(output)
    if ec != 0 or output == "\n":
        logger.warning("pod2rst failed on %s." % podfile)
        return None
    else:
        return output


def cleanup_content(markdown, cleanup_options):
    """Run several cleaners on the content we get from perl files."""
    for source, content in markdown.iteritems():
        if not source.endswith('.pan'):
            for fn in ['remove_emails', 'remove_headers', 'remove_whitespace', 'codify_paths']:
                if cleanup_options[fn]:
                    content = globals()[fn](content)
            markdown[source] = content

    return markdown


def remove_emails(markdown):
    """Remove email adresses from markdown."""
    replace = False
    for email in re.findall(MAILREGEX, markdown):
        logger.debug("Found %s." % email[0])
        replace = True
        if email[0].startswith('//'):
            replace = False
        for ignoremail in EXAMPLEMAILS:
            if ignoremail in email[0]:
                replace = False

        if replace:
            logger.debug("Removed it from line.")
            markdown = markdown.replace(email[0], '')

    return markdown


def remove_headers(markdown):
    """Remove MAINTAINER and AUTHOR headers from md files."""
    for header in ['# AUTHOR', '# MAINTAINER']:
        if header in markdown:
            markdown = markdown.replace(header, '')

    return markdown


def remove_whitespace(markdown):
    """Remove extra whitespace (3 line breaks)."""
    if '\n\n\n' in markdown:
        markdown = markdown.replace('\n\n\n', '\n')
        markdown = remove_whitespace(markdown)

    return markdown


def codify_paths(markdown):
    """Put paths into code tags."""
    markdown, counter = PATHREGEX.subn(r'\1`\2`\3', markdown)
    if counter > 0:
        markdown = codify_paths(markdown)
    return markdown
