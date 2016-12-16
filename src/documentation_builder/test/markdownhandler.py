"""Test class for markdownhandler."""

import sys
import os
import shutil
import filecmp
from tempfile import mkdtemp
from unittest import TestCase, main, TestLoader

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../lib')))  # noqa
from quattordocbuild import markdownhandler as mdh


class MarkdownHandlerTest(TestCase):
    """Test class for markdownhandler."""

    def setUp(self):
        """Set up temmp dir for tests."""
        self.tmpdir = mkdtemp()

    def tearDown(self):
        """Remove temp dir."""
        shutil.rmtree(self.tmpdir)

    def test_markdown_from_perl(self):
        """Test convert_pod_to_markdown function."""
        testinput = "test/testdata/pod_test_input.pod"
        testoutput = os.path.join(self.tmpdir, "test.md")
        expectedoutput = "test/testdata/markdown_from_pod.md"

        # Get False from bogus input
        self.assertFalse(mdh.markdown_from_perl("test"))

        # Verify content
        output = mdh.markdown_from_perl(testinput)
        file = open(testoutput, 'w')
        file.write(output)
        file.close()
        self.assertTrue(filecmp.cmp(testoutput, expectedoutput))

    def test_generate_markdown(self):
        """Test generate_markdown."""
        testdir = os.path.join(self.tmpdir, "testdata/target")
        testfile1 = os.path.join(testdir, "pan_annotated_schema.pan")
        testfile2 = os.path.join(testdir, "pod_test_input.pod")
        os.makedirs(testdir)
        shutil.copy("test/testdata/pan_annotated_schema.pan", testfile1)
        shutil.copy("test/testdata/pod_test_input.pod", testfile2)
        output = mdh.generate_markdown([testfile1, testfile2])
        self.assertEquals(len(output), 2)
        self.assertEquals(sorted(output.keys()), [testfile1, testfile2])

    def test_remove_mail(self):
        """Test remove_mail function."""
        mailtext = "Hello: mail@mailtest.mail mister."
        self.assertEquals(mdh.remove_mail(mailtext), "Hello:  mister.")
        mailtext = "Hello: //mail@mailtest.mail mister."
        self.assertEquals(mdh.remove_mail(mailtext), mailtext)
        mailtext = "Hello: example@example.com"
        self.assertEquals(mdh.remove_mail(mailtext), mailtext)

    def test_remove_headers(self):
        """Test remove_headers function."""
        headertext = "This is a \n test TEXT with AUTH and ication."
        self.assertEquals(mdh.remove_headers(headertext), headertext)
        headertext = "This is # MAINTAINER and # AUTHOR text \n with newlines."
        self.assertEquals(mdh.remove_headers(headertext), "This is  and  text \n with newlines.")

    def test_remove_whitespace(self):
        """Test remove_whitespace function."""
        whitetext = "this \n\n\n\n\n is a bit too much."
        self.assertEquals(mdh.remove_whitespace(whitetext), "this \n is a bit too much.")
        whitetext = "this \n is much better \n\n."
        self.assertEquals(mdh.remove_whitespace(whitetext), whitetext)

    def test_decrease_title_size(self):
        """Test decrease_title_size function."""
        titletext = "\n\n# very big title\n it is."
        self.assertEquals(mdh.decrease_title_size(titletext), '\n\n### very big title\n it is.')
        titletext = "\n## Smaller title."
        self.assertEquals(mdh.decrease_title_size(titletext), '\n#### Smaller title.')
        titletext = "# test with set() and ## others Should \n# Deliver \n # not someting weird."
        expected = '\n### test with set() and ## others Should \n### Deliver \n # not someting weird.'
        self.assertEquals(mdh.decrease_title_size(titletext), expected)

    def test_codify_paths(self):
        """Test codify_paths function."""
        txt = "leave / me alone//"
        self.assertEquals(mdh.codify_paths(txt), txt)
        txt = " /but/please/change/me/yes"
        self.assertEquals(mdh.codify_paths(txt), ' `/but/please/change/me/yes`')
        txt = "\n /even/if/i/have/multiline/in/me/ \n"
        self.assertEquals(mdh.codify_paths(txt), '\n `/even/if/i/have/multiline/in/me`/ \n')
        txt = " /or/even/if/i/have \n\n   /several/paths/that/have/coding "
        self.assertEquals(mdh.codify_paths(txt), ' `/or/even/if/i/have` \n\n   `/several/paths/that/have/coding` ')

    def test_cleanup_content(self):
        """Test cleanup_content."""
        opts = {
            'codify_paths': True,
            'remove_emails': True,
            'remove_whitespace': True,
            'remove_headers': True,
            'small_titles': True
        }
        text = {"/tmp/testfile": "# MAINTAINER \n# Title \n\n\n\n\n /path/to/test/on \n test@test.com"}
        self.assertEquals(mdh.cleanup_content(text, opts), {'/tmp/testfile': ' \n### Title \n `/path/to/test/on` \n '})

    def suite(self):
        """Return all the testcases in this module."""
        return TestLoader().loadTestsFromTestCase(MarkdownHandlerTest)

if __name__ == '__main__':
    main()
