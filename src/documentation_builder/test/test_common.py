"""
Test class for common tests.

Mainly runs prospector on project.
"""

import sys
import os
from prospector.run import Prospector
from prospector.config import ProspectorConfig
from unittest import TestCase, main, TestLoader
import pprint


class CommonTest(TestCase):
    """Class for all common tests."""

    def setUp(self):
        """Cleanup after running a test."""
        self.orig_sys_argv = sys.argv
        self.REPO_BASE_DIR = os.path.dirname(os.path.abspath(sys.argv[0]))
        super(CommonTest, self).setUp()

    def tearDown(self):
        """Cleanup after running a test."""
        sys.argv = self.orig_sys_argv
        super(CommonTest, self).tearDown()

    def test_prospector(self):
        """Run prospector on project."""
        sys.argv = ['fakename']
        sys.argv.append(self.REPO_BASE_DIR)

        config = ProspectorConfig()
        prospector = Prospector(config)
        prospector.execute()

        failures = []
        for msg in prospector.get_messages():
            failures.append(msg.as_dict())

        self.assertFalse(failures, "prospector failures: %s" % pprint.pformat(failures))

    def suite(self):
        """Return all the testcases in this module."""
        return TestLoader().loadTestsFromTestCase(CommonTest)

if __name__ == '__main__':
    main()
