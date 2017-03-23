"""Module to handle rst operations."""

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


def generate_rst(sources):
    """Generate rst."""
    logger.info("Generating rst files.")

    rstlist = {}

    for title, source in sources.iteritems():
        logger.debug("Parsing %s." % source)
        if source.endswith(".pan"):
            rst = rst_from_pan(source, title)
            if rst is not None:
                rstlist[source] = rst
        else:
            rst = rst_from_perl(source, title)
            if rst is not None:
                rstlist[source] = rst

    return rstlist


def rst_from_perl(podfile, title):
    """
    Take a perl file and converts it to a reStrcturedText with the help of pod2rst.

    Returns True if pod2rst worked, False if it failed.
    """
    logger.info("Making rst from perl: %s." % podfile)
    ec, output = run_asyncloop("pod2rst --infile %s --title %s" % (podfile, title))
    logger.debug(output)
    if ec != 0 or output == "\n":
        logger.warning("pod2rst failed on %s." % podfile)
        return None
    else:
        return output


def cleanup_content(rst, cleanup_options):
    """Run several cleaners on the content we get from perl files."""
    for source, content in rst.iteritems():
        if not source.endswith('.pan'):
            for fn in ['remove_emails', 'codify_paths']:
                if cleanup_options[fn]:
                    content = globals()[fn](content)
            rst[source] = content

    return rst


def remove_emails(rst):
    """Remove email adresses from rst."""
    replace = False
    for email in re.findall(MAILREGEX, rst):
        logger.debug("Found %s." % email[0])
        replace = True
        if email[0].startswith('//'):
            replace = False
        for ignoremail in EXAMPLEMAILS:
            if ignoremail in email[0]:
                replace = False

        if replace:
            logger.debug("Removed it from line.")
            rst = rst.replace(email[0], '')

    return rst


def codify_paths(rst):
    """Put paths into code tags."""
    rst, counter = PATHREGEX.subn(r'\1`\2`\3', rst)
    if counter > 0:
        rst = codify_paths(rst)
    return rst
