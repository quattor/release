#!/usr/bin/env python3

import logging
from urllib.request import urlopen
from json import load
from datetime import datetime, timedelta
from os.path import exists, isdir, join, abspath
from os import chdir, makedirs, sep
from shutil import rmtree
from tempfile import mkdtemp
from sys import exit as sys_exit
from argparse import ArgumentParser
import subprocess
import errno

RELEASES_URL = 'http://www.quattor.org/release/releases.json'
LIBRARY_URL_PATTERN = 'https://github.com/quattor/template-library-%s.git'
LIBRARY_BRANCHES = {
    'core': ['main'],
    'grid': ['main'],
    'os': ['main'],
    'standard': ['main'],
    'openstack': ['mitaka', 'newton', 'ocata'],
}

BIN_GIT = '/usr/bin/git'
BIN_RSYNC = '/usr/bin/rsync'


def execute(command):
    """Wrapper around subprocess, calls an external process, logging stdout and stderr to debug"""
    logger = logging.getLogger()
    if command:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output, error = process.communicate()
        logger.debug('Executed %s, stdout: "%s", stderr: "%s"', command[0], output.strip(), error.strip())
        if process.returncode > 0:
            logger.error('Executed %s with errors: "%s"', command[0], error.strip())
            return False
        return True

    logger.error('Called execute without specifing a command to run')
    return False


def make_target_dir(directory):
    """Create specified directory. Stay silent if it already exists, but complain loudly if it isn't a directory"""
    logger = logging.getLogger()
    try:
        makedirs(directory)
        logger.debug('Created directory %s', directory)
        return True
    except OSError as err:
        if err.errno != errno.EEXIST:
            raise
        if exists(directory):
            if isdir(directory):
                logger.debug('Directory %s already exists', directory)
            else:
                logger.error('Tried to create directory %s, but it already exists and is not a directory', directory)
    return False


def get_release_dates():
    # logger = logging.getLogger()
    releases = load(urlopen(RELEASES_URL))
    results = []
    for release, properties in releases.items():
        release = f'{release}.0'
        release_date = datetime.strptime(properties['target'], '%Y-%m-%d')
        results.append((release, release_date))
    return results


def get_current_releases():
    logger = logging.getLogger()
    results = []
    now = datetime.now()
    threshold = now - timedelta(days=365)
    for release, release_date in get_release_dates():
        if release_date < now:
            if release_date > threshold:
                results.append(release)
            else:
                logger.debug('Skipping %s, release was too far in the past', release)
        else:
            logger.debug('Skipping %s, release is in the future', release)
    return results


def sync_template_library(base_dir, releases):
    logger = logging.getLogger()

    logger.debug('Using %s as base directory for releases %s', base_dir, ', '.join(releases))

    for library, branches in LIBRARY_BRANCHES.items():
        logger.info('Processing library %s', library)

        url = LIBRARY_URL_PATTERN % (library)
        temp_dir = mkdtemp(prefix='quattor-template-library_')
        logger.info('Cloning %s to %s', url, temp_dir)
        execute([BIN_GIT, 'clone', url, temp_dir])
        chdir(temp_dir)
        logger.info('Done')

        for release in releases:
            logger.info('Release %s available', release)

            for branch in branches:
                logger.info('  Processing branch %s', branch)
                tag = release

                target_dir = join(base_dir, release, library)
                logger.debug('Target dir is %s', target_dir)
                if branch != 'main':
                    tag = f'{branch}-{tag}'
                    target_dir = join(target_dir, branch)
                    logger.debug('Added branch to target dir, which is now %s', target_dir)

                make_target_dir(target_dir)

                logger.info('  Checking out tag %s', tag)
                if execute([BIN_GIT, 'checkout', tag]):
                    source = temp_dir + sep
                    target = target_dir + sep
                    logger.info('  rsyncing tag from %s to %s', source, target)
                    execute([BIN_RSYNC, '-rtx', '--exclude=.*', source, target])

        chdir(base_dir)
        try:
            rmtree(temp_dir)
            logger.debug('Removed temporary directory %s', temp_dir)
        except OSError as err:
            logger.error('Caught exception %s trying to remove temporary directory %s', temp_dir, err)


def main():
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

    parser = ArgumentParser(description='Synchronise quattor template libraries')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    parser.add_argument('--releases', help='Sync specific release(s), delimit multiple releases with commas')
    parser.add_argument(
        'path',
        metavar='PATH',
        type=str,
        help='Target base path for template library',
    )
    args = parser.parse_args()

    logger = logging.getLogger()
    if args.debug:
        logger.setLevel(logging.DEBUG)

    if args.releases:
        releases = args.releases.split(',')
    else:
        releases = get_current_releases()

    sync_template_library(abspath(args.path), releases)

    sys_exit(0)


if __name__ == '__main__':
    main()
