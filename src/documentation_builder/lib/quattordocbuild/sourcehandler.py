"""
Module to handle 'source' related actions.

It contains functions to run maven clean and compile,
scan a whole tree for files and find '.pan' files and perl
files, where when there is a duplicate between '.pod' and
'.pl', the pod file has the preference.
"""

import os

from vsc.utils import fancylogger
from vsc.utils.run import run_asyncloop

logger = fancylogger.getLogger()


def maven_clean_compile(location):
    """Execute mvn clean and mvn compile in the given modules_location."""
    logger.info("Doing maven clean compile in %s." % location)
    ec, output = run_asyncloop("mvn clean compile", startpath=location)
    logger.debug(output)
    return ec


def is_wanted_dir(path, files):
    """
    Check if the directory matches required criteria.

     - It must be in 'target directory'
     - It should contain files
     - it shoud contain one of the following in the path:
        - doc/pod
        - lib/perl
        - pan
    """
    if 'target' not in path:
        return False
    if len(files) == 0:
        return False
    if True not in [substr in path for substr in ["doc/pod", "lib/perl", "pan"]]:
        return False
    return True


def is_wanted_file(path, filename):
    """
    Check if the file matches one of the criteria.

     - a perl file based on extension
     - a pan file based on extension (.pan)
     - a perl file based on shebang
    """
    if True in [filename.endswith(ext) for ext in [".pod", ".pm", ".pl"]]:
        return True
    if filename.endswith(".pan"):
        return True
    if len(filename.split(".")) < 2:
        with open(os.path.join(path, filename), 'r') as pfile:
            if 'perl' in pfile.readline():
                return True
    return False


def handle_duplicates(file, path, fulllist):
    """Handle duplicates, pod takes preference over pm."""
    if "doc/pod" in path:
        duplicate = path.replace('doc/pod', 'lib/perl')
        if file.endswith('.pod'):
            duplicate = duplicate.replace(".pod", ".pm")
            if duplicate in fulllist:
                fulllist[fulllist.index(duplicate)] = path
                return fulllist

    if "lib/perl" in path:
        duplicate = path.replace('lib/perl', 'doc/pod')
        if file.endswith('.pm'):
            duplicate = duplicate.replace(".pm", ".pod")
            if duplicate not in fulllist:
                fulllist.append(path)
                return fulllist
            else:
                return fulllist
    fulllist.append(path)
    return fulllist


def list_source_files(location):
    """
    Return a list of source_files in a location.

    Try to filter out:
     - Unwanted locations
     - Unwanted files
     - Duplicates, pod takes precedence over pm.
    """
    logger.info("Looking for source files.")
    finallist = []
    for path, _, files in os.walk(location):
        if not is_wanted_dir(path, files):
            continue

        for file in files:
            if is_wanted_file(path, file):
                fullpath = os.path.join(path, file)
                finallist = handle_duplicates(file, fullpath, finallist)
    return finallist


def get_source_files(location, compile):
    """Run maven compile and get all source files."""
    if compile:
        ec = maven_clean_compile(location)
        if ec != 0:
            logger.error("Something went wrong running maven in %s." % location)
            return None

    sources = list_source_files(location)
    logger.info("Found %s source files." % len(sources))
    return sources
