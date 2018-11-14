"""
Module to handle 'source' related actions.

It contains functions to run maven clean and compile,
scan a whole tree for files and find '.pan' files and perl
files, where when there is a duplicate between '.pod' and
'.pl', the pod file has the preference.
"""

import os
import re
import shutil
from vsc.utils import fancylogger
from vsc.utils.run import asyncloop
from repo import Sourcepage

logger = fancylogger.getLogger()


def maven_clean_compile(location):
    """Execute mvn clean and mvn compile in the given location."""
    logger.info("Doing maven clean compile in %s.", location)
    errc, output = asyncloop(["mvn", "clean", "compile"], startpath=location)
    logger.debug(output)
    return errc


def is_wanted_dir(path, wanted_dirs):
    """Check if the directory matches required criteria."""
    logger.debug("testing dir: %s", path)
    if True not in [substr in path for substr in wanted_dirs]:
        return False
    return True


def is_wanted_file(path, filename, extensions):
    """Check if the file matches one of the criteria."""
    logger.debug("testing file: %s", os.path.join(path, filename))
    if True in [filename.endswith(ext) for ext in extensions]:
        return True
    logger.debug("File not retained for further usage.")
    return False

def rreplace(orig_str, old, new):
    """Replace right most occurence of a substring."""
    list_str = orig_str.rsplit(old, 1) #Split only once
    return new.join(list_str)


def make_title_from_source(source, repository):
    """Make a title based on source path."""
    logger.debug('making title from source %s', source)
    title = ""

    for sourcepath in repository.sourcepaths:
        if sourcepath in source:
            title = source.replace(sourcepath, '')
            logger.debug("title 1: %s", title)

    for subdir in repository.subdirs:
        title = title.replace(subdir, '')
        logger.debug("title 2: %s", title)

    for wanted_dir in repository.wanted_dirs:
        title = title.replace(wanted_dir, '')
        logger.debug("title 3: %s", title)

    if title.endswith('.pan'):
        title = rreplace(title, '/', ' - ')
        if repository.title_pan_prefix:
            title = '%s%s' % (repository.title_pan_prefix, title)
        logger.debug("title 4: %s", title)

    title = os.path.splitext(title)[0]

    if repository.title_remove:
        for remover in repository.title_remove:
            title = re.sub(remover, '', title, count=1)
        logger.debug("title 5: %s", title)

    if repository.title_prefix:
        title = '%s%s' % (repository.title_prefix, title)

    title = re.sub(r'\/+', '/', title)
    title = title.lstrip('/')
    title = title.replace('/', '\::')

    logger.debug("title 6: %s", title)
    return title

def handle_duplicates(filename, path, fulllist):
    """Handle duplicates, pod takes preference over pm."""
    if "doc/pod" in path:
        duplicate = path.replace('doc/pod', 'lib/perl')
        if filename.endswith('.pod'):
            duplicate = duplicate.replace(".pod", ".pm")
            if duplicate in fulllist:
                fulllist[fulllist.index(duplicate)] = path
                return fulllist

    if "lib/perl" in path:
        duplicate = path.replace('lib/perl', 'doc/pod')
        if filename.endswith('.pm'):
            duplicate = duplicate.replace(".pm", ".pod")
            if duplicate not in fulllist:
                fulllist.append(path)
                return fulllist
            else:
                return fulllist
    fulllist.append(path)
    return fulllist


def list_source_files(repository):
    """
    Return a list of source_files in a location.

    Try to filter out:
     - Unwanted locations
     - Unwanted files
     - Duplicates, pod takes precedence over pm.
    """
    finallist = []
    for sourcepath in repository.sourcepaths:
        logger.info("Looking for source files in %s.", sourcepath)
        for path, _, files in os.walk(sourcepath):
            if not is_wanted_dir(path, repository.wanted_dirs):
                continue

            for sfile in files:
                if is_wanted_file(path, sfile, repository.wanted_extensions):
                    fullpath = os.path.join(path, sfile)
                    finallist = handle_duplicates(sfile, fullpath, finallist)
    return finallist

def movefiles(repository):
    logger.debug('Moving files.')
    for source, destination, ignorepatterns in repository.movefiles:
        source = os.path.join(repository.path, source)
        destination = os.path.join(repository.path, destination)
        shutil.copytree(source, destination, ignore=shutil.ignore_patterns(*ignorepatterns))

        for root, dirs, files in os.walk(destination):
            if root.endswith('/pan'):
                for sfile in files:
                    shutil.move(os.path.join(root,sfile), os.path.join(root, '..', sfile))
                for sdir in dirs:
                    shutil.move(os.path.join(root,sdir), os.path.join(root, '..', sdir))
                shutil.rmtree(root)

def get_source_files(repository):
    """Run maven compile and get all source files."""
    if repository.mvncompile:
        for path in repository.sourcepaths:
            errc = maven_clean_compile(path)
            if errc != 0:
                logger.error("Something went wrong running maven in %s.", path)
                return None

    if repository.movefiles:
        movefiles(repository)
    sources = list_source_files(repository)
    for source in sources:
        title = make_title_from_source(source, repository)
        sourcepage = Sourcepage(title, source, repository.pan_path_prefix,
                                repository.pan_guess_basename)
        repository.sources.append(sourcepage)
    logger.info("Found %s source files.", len(sources))

    return repository
