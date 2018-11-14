"""Test module for config.py."""

import sys
import os
import shutil
from tempfile import mkdtemp
from unittest import TestCase, main, TestLoader
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../lib')))  # noqa
from quattordocbuild import config


class ConfigTest(TestCase):
    """Test class for config.py."""

    def setUp(self):
        """Set up temp dir for tests."""
        self.tmpdir = mkdtemp()

    def tearDown(self):
        """Remove temp dir."""
        shutil.rmtree(self.tmpdir)

    def test_build_repository_map(self):
        """Test build_repository_map function."""
        testdir1 = os.path.join(self.tmpdir, "repo")
        testdir2 = os.path.join(self.tmpdir, "repo1")
        os.makedirs(testdir1)
        os.makedirs(testdir2)
        self.assertFalse(config.build_repository_map(self.tmpdir, {}))

    def suite(self):
        """Return all the testcases in this module."""
        return TestLoader().loadTestsFromTestCase(ConfigTest)

if __name__ == '__main__':
    main()
