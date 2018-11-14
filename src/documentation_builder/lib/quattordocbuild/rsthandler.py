"""Module to handle rst operations."""

import re

from vsc.utils import fancylogger
from vsc.utils.run import asyncloop
from panhandler import rst_from_pan
import restructuredtext_lint

logger = fancylogger.getLogger()

MAILREGEX = re.compile(("([a-zA-Z0-9!#$%&'*+\/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+\/=?^_`"
                        "{|}~-]+)*(@|\sat\s)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(\.|"
                        "\sdot\s))+[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)"))
PATHREGEX = re.compile(r'(\s+)((?:/[\w{}]+)+\.?\w*)(\s*)')
EXAMPLEMAILS = ["example", "username", "system.admin"]


def generate_rst(sourcepage):
    """Generate rst."""
    logger.debug("Parsing %s.", sourcepage)
    rst = None
    if sourcepage.path.endswith(".pan"):
        rst = rst_from_pan(sourcepage.path, sourcepage.title, sourcepage.pan_path_prefix,
                           sourcepage.pan_guess_basename)
    else:
        rst = rst_from_perl(sourcepage.path, sourcepage.title)

    # contains more than a title
    if rst is not None and rst.count('\n') > 6:
        sourcepage.rstcontent = rst

    return sourcepage


def rst_from_perl(podfile, title):
    """Take a perl file and converts it to a reStructuredText with the help of pod2rst."""
    logger.info("Making rst from perl: %s.", podfile)
    errc, output = asyncloop(["pod2rst", "--infile", podfile, "--title", title])
    logger.debug(output)
    if errc != 0 or output == "\n":
        logger.warning("pod2rst failed on %s.", podfile)
        output = None
    return output


def cleanup_content(sourcepage, remove_emails, codify_paths, clean_code_tags):
    """Run several cleaners on the content we get from perl files."""

    content = sourcepage.rstcontent
    if not sourcepage.path.endswith('.pan'):
        for func in ['remove_emails', 'codify_paths', 'clean_code_tags']:
            if func:
                content = globals()[func](content)

    sourcepage.rstcontent = content

    return sourcepage


def remove_emails(rst):
    """Remove email adresses from rst."""
    replace = False
    for email in re.findall(MAILREGEX, rst):
        logger.debug("Found %s.", email[0])
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


def clean_code_tags(rst):
    regex = r'\\ ``(.*?)``\\ '
    regex = re.compile(regex)
    rst, counter = regex.subn(r'``\1``', rst)
    if counter > 0:
        rst = clean_code_tags(rst)
    return rst


def lint_content(sourcepage):
    errors = restructuredtext_lint.lint(sourcepage.rstcontent)
    if errors:
        for error in errors:
            if 'Title overline too short' in error.message:
                logger.debug("Fixing 'Title overline too short'.")
                splitlines = sourcepage.rstcontent.splitlines()
                chartoadd = splitlines[error.line - 1][:1]
                while len(splitlines[error.line - 1]) < len(splitlines[error.line]):
                    splitlines[error.line - 1] = chartoadd + splitlines[error.line - 1]

                sourcepage.rstcontent = '\n'.join(splitlines)
                sourcepage = lint_content(sourcepage)
                break

            if 'Title underline too short' in error.message:
                logger.debug("Fixing 'Title underline too short'.")
                splitlines = sourcepage.rstcontent.splitlines()
                chartoadd = splitlines[error.line - 1][:1]
                while len(splitlines[error.line - 1]) < len(splitlines[error.line - 2]):
                    splitlines[error.line - 1] = chartoadd + splitlines[error.line - 1]

                sourcepage.rstcontent = '\n'.join(splitlines)
                sourcepage = lint_content(sourcepage)
                break

            if 'Title overline & underline mismatch' in error.message:
                logger.debug("Fixing 'Title underline too short'.")
                splitlines = sourcepage.rstcontent.splitlines()
                chartoadd = splitlines[error.line - 1][:1]
                while len(splitlines[error.line + 1]) < len(splitlines[error.line - 1]):
                    splitlines[error.line + 1] = chartoadd + splitlines[error.line + 1]

                sourcepage.rstcontent = '\n'.join(splitlines)
                sourcepage = lint_content(sourcepage)
                break

            if 'Bullet list ends without a blank line; unexpected unindent' in error.message:
                logger.debug("Fixing 'Bullet list ends without a blank line'.")
                splitlines = sourcepage.rstcontent.splitlines()
                splitlines[error.line - 2] = '%s %s' %(splitlines[error.line - 2], splitlines[error.line - 1])
                del splitlines[error.line - 1]
                sourcepage.rstcontent = '\n'.join(splitlines)
                sourcepage = lint_content(sourcepage)
                break


            #don't log info
            elif error.level > 1:
                logger.error('%s contains a problem on line %s: %s',sourcepage.title, error.line - 1, error.message)
                splitlines = sourcepage.rstcontent.splitlines()
                for linenumber in xrange(error.line - 5, error.line + 5):
                    try:
                        logger.warning('%s - %s', linenumber, splitlines[linenumber])
                    except IndexError:
                        # hit the end of the page
                        pass

    return sourcepage

def generate_rst_from_repository(repository):

    generated_sources = []
    for sourcepage in repository.sources:
        sourcepage = generate_rst(sourcepage)
        if sourcepage.rstcontent:
            sourcepage = cleanup_content(sourcepage, repository.remove_emails, repository.codify_paths, repository.clean_code_tags)
            sourcepage = lint_content(sourcepage)
            generated_sources.append(sourcepage)

    repository.sources = generated_sources
    return repository
