"""Test class for rsthandler."""

import sys
import os
import shutil
import filecmp
from tempfile import mkdtemp
from unittest import TestCase, main, TestLoader

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../lib')))  # noqa
from quattordocbuild import rsthandler as rsth
from quattordocbuild import repo

class RstHandlerTest(TestCase):
    """Test class for rsthandler."""

    def setUp(self):
        """Set up temp dir for tests."""
        self.tmpdir = mkdtemp()

    def tearDown(self):
        """Remove temp dir."""
        shutil.rmtree(self.tmpdir)

    def test_rst_from_perl(self):
        """Test rst_from_perl function."""
        testinput = "test/testdata/pod_test_input.pod"
        testoutput = os.path.join(self.tmpdir, "test.rst")
        expectedoutput = "test/testdata/rst_from_pod.rst"

        # Get False from bogus input
        self.assertFalse(rsth.rst_from_perl("nonexistent_file", "allo"))

        # Verify content
        output = rsth.rst_from_perl(testinput, "testtitle")
        print output
        file = open(testoutput, 'w')
        file.write(output)
        file.close()
        self.assertTrue(filecmp.cmp(testoutput, expectedoutput))

    def test_generate_rst(self):
        """Test generate_rst."""
        testdir = os.path.join(self.tmpdir, "testdata/target")
        testfile1 = os.path.join(testdir, "pan_annotated_schema.pan")
        testfile2 = os.path.join(testdir, "pod_test_input.pod")
        os.makedirs(testdir)
        shutil.copy("test/testdata/pan_annotated_schema.pan", testfile1)
        shutil.copy("test/testdata/pod_test_input.pod", testfile2)

        tfil1 = repo.Sourcepage('title1', testfile1, False, False)
        tfil2 = repo.Sourcepage('title2', testfile2, False, False)

        output = rsth.generate_rst([tfil1, tfil2])
        self.assertEquals(len(output), 2)

    def test_remove_emails(self):
        """Test remove_emails function."""
        mailtext = "Hello: mail@mailtest.mail mister."
        self.assertEquals(rsth.remove_emails(mailtext), "Hello:  mister.")
        mailtext = "Hello: //mail@mailtest.mail mister."
        self.assertEquals(rsth.remove_emails(mailtext), mailtext)
        mailtext = "Hello: example@example.com"
        self.assertEquals(rsth.remove_emails(mailtext), mailtext)

    def test_codify_paths(self):
        """Test codify_paths function."""
        txt = "leave / me alone//"
        self.assertEquals(rsth.codify_paths(txt), txt)
        txt = " /but/please/change/me/yes"
        self.assertEquals(rsth.codify_paths(txt), ' `/but/please/change/me/yes`')
        txt = "\n /even/if/i/have/multiline/in/me/ \n"
        self.assertEquals(rsth.codify_paths(txt), '\n `/even/if/i/have/multiline/in/me`/ \n')
        txt = " /or/even/if/i/have \n\n   /several/paths/that/have/coding "
        self.assertEquals(rsth.codify_paths(txt), ' `/or/even/if/i/have` \n\n   `/several/paths/that/have/coding` ')

    def test_cleanup_content(self):
        """Test cleanup_content."""
        verify = repo.Sourcepage('test', '/tmp/testfile', False, False)
        verify.rstcontent = '`/path/to/test/on`'
        testpage = repo.Sourcepage('test', '/tmp/testfile', False, False)
        testpage.rstcontent = "/path/to/test/on test@test.com"
        self.assertEquals(rsth.cleanup_content([testpage, ]), [verify, ])

    def suite(self):
        """Return all the testcases in this module."""
        return TestLoader().loadTestsFromTestCase(RstHandlerTest)

if __name__ == '__main__':
    main()
