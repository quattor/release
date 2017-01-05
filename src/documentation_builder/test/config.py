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

    def test_check_repository_map(self):
        """Test check repository_map function."""
        self.assertFalse(config.check_repository_map(None))
        self.assertFalse(config.check_repository_map({}))
        self.assertFalse(config.check_repository_map({"test": {}}))
        self.assertFalse(config.check_repository_map({"test": {"sitesection": "test"}}))
        self.assertFalse(config.check_repository_map({"test": {"targets": ["test"]}}))
        repomap = {'test': {'sitesection': 'components', 'targets': ['/NCM/Component', 'components']}}
        self.assertTrue(config.check_repository_map(repomap))

    def test_build_repository_map(self):
        """Test build_repository_map function."""
        testdir1 = os.path.join(self.tmpdir, "repo")
        testdir2 = os.path.join(self.tmpdir, "repo1")
        os.makedirs(testdir1)
        os.makedirs(testdir2)
        self.assertFalse(config.build_repository_map(self.tmpdir))
        open(os.path.join(testdir1, config.cfgfile), 'a').close()
        self.assertFalse(config.build_repository_map(self.tmpdir))

    def test_read_config(self):
        """Test read_config function."""
        testfile = os.path.join(self.tmpdir, config.cfgfile)
        with open(testfile, 'w') as fih:
            fih.write("\n")
        self.assertFalse(config.read_config(testfile))
        with open(testfile, 'a') as fih:
            fih.write("[docbuilder]\nsitesection=test\n")
        self.assertFalse(config.read_config(testfile))
        with open(testfile, 'a') as fih:
            fih.write("targets=test")
        self.assertEquals(config.read_config(testfile), {'sitesection': 'test',
                                                         'subdir': None,
                                                         'targets': ['test']})
        with open(testfile, 'a') as fih:
            fih.write(",test2")
        self.assertEquals(config.read_config(testfile), {'sitesection': 'test',
                                                         'subdir': None,
                                                         'targets': ['test', 'test2']})
        with open(testfile, 'a') as fih:
            fih.write(", \n")
        self.assertEquals(config.read_config(testfile), {'sitesection': 'test',
                                                         'subdir': None,
                                                         'targets': ['test', 'test2']})
        with open(testfile, 'a') as fih:
            fih.write("subdir=test3\n")
        self.assertEquals(config.read_config(testfile), {'sitesection': 'test',
                                                         'subdir': 'test3',
                                                         'targets': ['test', 'test2']})

    def suite(self):
        """Return all the testcases in this module."""
        return TestLoader().loadTestsFromTestCase(ConfigTest)

if __name__ == '__main__':
    main()
