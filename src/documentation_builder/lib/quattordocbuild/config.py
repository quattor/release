"""Build and check configuration for quattor documentation."""

import os
from vsc.utils import fancylogger
from repo import Repo

logger = fancylogger.getLogger()

def build_repository_map(location):
    """Build a repository mapping for repository_location."""
    logger.info("Building repository map in %s.", location)
    root_dirs = [f for f in os.listdir(location) if os.path.isdir(os.path.join(location, f))]
    logger.debug("root directories: %s", root_dirs)
    repomap = []
    for repo in root_dirs:
        repository = Repo(repo, os.path.join(location, repo))
        if repository and repository.check():
            repomap.append(repository)
        else:
            logger.warning('Repo "%s" not usable, skipping it.', repo)

    if not repomap:
        repomap = False
    return repomap
