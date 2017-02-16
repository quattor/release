"""Test class for sourcehandler."""
import os
import sys
import shutil
from tempfile import mkdtemp
from unittest import TestCase, main, TestLoader

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../lib')))  # noqa
from quattordocbuild import sourcehandler


class SourcehandlerTest(TestCase):
    """Test class for sourcehandler."""

    def setUp(self):
        """Set up temp dir for tests."""
        self.tmpdir = mkdtemp()

    def tearDown(self):
        """Remove temp dir."""
        shutil.rmtree(self.tmpdir)

    def test_maven_clean_compile(self):
        """Test maven_clean_compile."""
        repoloc = os.path.join(self.tmpdir, "test")
        os.makedirs(repoloc)

        # test if it fails on a empty dir
        self.assertNotEqual(sourcehandler.maven_clean_compile(repoloc), 0)

        # test if it can run a basic pom.xml and return 0
        file = open(os.path.join(repoloc, "pom.xml"), "w")
        file.write('<project><modelVersion>4.0.0</modelVersion><groupId>test</groupId>')
        file.write('<artifactId>test</artifactId><version>1</version></project>')
        file.close()

        self.assertEqual(sourcehandler.maven_clean_compile(repoloc), 0)

    def test_is_wanted_file(self):
        """Test is_wanted_file function."""
        # Test valid extensions
        for extension in ['pod', 'pm', 'pl', 'pan']:
            testfile = "test.%s" % extension
            self.assertTrue(sourcehandler.is_wanted_file('', testfile))

        # Test invalid extensions
        for extension in ['tpl', 'txt', 'xml']:
            testfile = "test.%s" % extension
            self.assertFalse(sourcehandler.is_wanted_file('', testfile))

        # Test valid shebang
        testfilename = "test"
        file = open(os.path.join(self.tmpdir, testfilename), "w")
        file.write('#!/usr/bin/perl\n')
        file.close()
        self.assertTrue(sourcehandler.is_wanted_file(self.tmpdir, testfilename))

        # Test invalid shebang
        file = open(os.path.join(self.tmpdir, testfilename), "w")
        file.write('#!/usr/bin/python\n')
        file.close()
        self.assertFalse(sourcehandler.is_wanted_file(self.tmpdir, testfilename))

    def test_is_wanted_dir(self):
        """Test is_wanted_dir function."""
        # Test we get False if target is not in the given path
        self.assertFalse(sourcehandler.is_wanted_dir('/bogusdir/test', []))

        # Test for False on empty fileslist
        self.assertFalse(sourcehandler.is_wanted_dir('/tmp/target/test/', []))

        # Test for wrong subdir
        self.assertFalse(sourcehandler.is_wanted_dir('/tmp/target/test/', ['schema.pan']))

        # Test for a correct path
        self.assertTrue(sourcehandler.is_wanted_dir('/tmp/target/doc/pod', ['schema.pan']))

    def test_handle_duplicates(self):
        """Test handle_duplicates function."""
        testperlfile = 'test/lib/perl/test.pm'
        testpodfile = 'test/doc/pod/test.pod'

        # Add a correct item to an empty list
        self.assertEquals(sourcehandler.handle_duplicates('test.pm', testperlfile, []),
                          ['test/lib/perl/test.pm'])

        # Add a pod file when a pm file is in the list, get a list with only the pod file back
        self.assertEquals(sourcehandler.handle_duplicates('test.pod', testpodfile, [testperlfile]), [testpodfile])

        # Add a pm file when a pod file is in the list, get a list with only the pod file back
        self.assertEquals(sourcehandler.handle_duplicates('test.pm', testperlfile, [testpodfile]), [testpodfile])

    def test_list_source_files(self):
        """Test list_source_files function."""
        # Test a bogus dir
        self.assertEquals(sourcehandler.list_source_files(self.tmpdir), [])

        # Test a correct dir
        testfile = 'test.pod'
        fulltestdir = os.path.join(self.tmpdir, 'target/doc/pod')
        os.makedirs(fulltestdir)
        file = open(os.path.join(fulltestdir, testfile), 'w')
        file.write("test\n")
        file.close()

        self.assertEquals(sourcehandler.list_source_files(fulltestdir), [os.path.join(fulltestdir, testfile)])

    def test_get_source_files(self):
        """Test get_source_files function."""
        self.assertEquals(sourcehandler.get_source_files(self.tmpdir, False), [])
        self.assertFalse(sourcehandler.get_source_files(self.tmpdir, True))

    def suite(self):
        """Return all the testcases in this module."""
        return TestLoader().loadTestsFromTestCase(SourcehandlerTest)

if __name__ == '__main__':
    main()
