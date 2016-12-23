"""Tests for panhandler."""

import sys
import os
import shutil
import filecmp
from tempfile import mkdtemp
from unittest import TestCase, main, TestLoader
from lxml import etree

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../lib')))  # noqa
from quattordocbuild import panhandler as panh


class PanHandlerTest(TestCase):
    """Test class for panhandler."""

    def setUp(self):
        """Set up temmp dir for tests."""
        self.tmpdir = mkdtemp()

    def tearDown(self):
        """Remove temp dir."""
        shutil.rmtree(self.tmpdir)

    def test_build_annotations(self):
        """Test build_annotations function."""
        # Get False with bogus input
        self.assertFalse(panh.build_annotations("testfile.pan", "test123", "test1234"))

        # Get True with valid input
        self.assertTrue(panh.build_annotations("pan_annotated_schema.pan", "test/testdata/", self.tmpdir))

        outputfile = os.path.join(self.tmpdir, "pan_annotated_schema.pan.annotation.xml")
        # Test if the output file exists
        self.assertTrue(os.path.exists(outputfile))

        # Verify the content
        self.assertTrue(filecmp.cmp("test/testdata/pan_annotated_output.xml", outputfile))

    def test_validate_annotations(self):
        """Test validate_annotations function."""
        # Test we skip empty files
        self.assertIsNone(panh.validate_annotations("test/testdata/pan_empty_annotated_output.xml"))
        # Test we get valid content back
        self.assertIsNotNone(panh.validate_annotations("test/testdata/pan_annotated_output.xml"))

    def test_get_types_and_functions(self):
        """Test get_types_and_functions function."""
        root = panh.validate_annotations("test/testdata/pan_annotated_output.xml")
        self.assertIsNotNone(panh.get_types_and_functions(root))

        el1 = self.create_element("test", "test")
        self.assertEquals(panh.get_types_and_functions(el1), (None, None))

    def create_element(self, name, text):
        """Create a XML element from name and text."""
        element = etree.Element(name)
        element.text = text
        return element

    def test_find_description(self):
        """Test find_description function."""
        # Test for an emtpy description
        el1 = self.create_element("test", "test")
        self.assertIsNone(panh.find_description(el1))

        # Test for a description tag
        el2 = self.create_element("%sdesc" % panh.namespace, "test")
        el1.append(el2)
        self.assertEquals(panh.find_description(el1).text, "test")

        # Test for a description tag within a documentation tag
        el3 = self.create_element("test", "test")
        el4 = self.create_element("%sdocumentation" % panh.namespace, "test")
        el2.text = "test2"
        el4.append(el2)
        el3.append(el4)
        self.assertEquals(panh.find_description(el3).text, "test2")

    def test_parse_type(self):
        """Test parse_type function."""
        # Test empty element
        el1 = self.create_element("type", "")
        self.assertEquals(panh.parse_type(el1), {'fields': [], 'name': None})

        # Test name
        el1.attrib['name'] = "test"
        self.assertEquals(panh.parse_type(el1), {'fields': [], 'name': 'test'})

        # Test description
        el2 = self.create_element("%sdesc" % panh.namespace, "testdesc")
        el1.append(el2)
        self.assertEquals(panh.parse_type(el1), {'desc': 'testdesc', 'fields': [], 'name': 'test'})

        # Test field
        el3 = self.create_element("basetype", "")
        el4 = self.create_element("%sfield" % panh.namespace, "")
        el4.attrib['name'] = 'debug'
        el4.attrib['required'] = 'true'
        el5 = self.create_element("%sbasetype" % panh.namespace, "")
        el5.attrib['name'] = 'string'
        el4.append(el5)
        el3.append(el4)
        el1.append(el3)
        expectedoutput = {'desc': 'testdesc',
                          'fields': [{'name': 'debug', 'required': 'true', 'type': 'string'}],
                          'name': 'test'}
        self.assertEquals(panh.parse_type(el1), expectedoutput)

    def test_parse_function(self):
        """Test parse_function function."""
        # Test empty input
        el1 = self.create_element("function", "")
        self.assertEquals(panh.parse_function(el1), {'args': [], 'name': None})

        # Test name
        el1.attrib['name'] = "testfunction"
        self.assertEquals(panh.parse_function(el1), {'args': [], 'name': 'testfunction'})

        # Test description
        el2 = self.create_element("%sdesc" % panh.namespace, "testdesc")
        el1.append(el2)
        self.assertEquals(panh.parse_function(el1), {'args': [], 'name': 'testfunction', 'desc': 'testdesc'})

        # Test args
        el3 = self.create_element("%sarg" % panh.namespace, "testargument")
        el4 = self.create_element("%sarg" % panh.namespace, "testargument2")
        el2.append(el3)
        el2.append(el4)
        expectedoutput = {'args': ['testargument', 'testargument2'], 'name': 'testfunction', 'desc': 'testdesc'}
        self.assertEquals(panh.parse_function(el1), expectedoutput)

    def test_render_template(self):
        """Test render_template function."""
        content = panh.get_content_from_pan("test/testdata/pan_annotated_schema.pan")
        testfile = open(os.path.join(self.tmpdir, "test.md"), 'w')

        output = panh.render_template(content, "component-test")
        print output
        for line in output:
            testfile.write(line)
        testfile.close()

        self.assertTrue(filecmp.cmp("test/testdata/markdown_from_pan.md", testfile.name))

        # Test with only fields
        content = {'functions': [{'args': ['first number to add'], 'name': 'add'}]}

        output = panh.render_template(content, "component-test")
        print output

        expectedoutput = "\n### Functions\n\n - add\n    - Arguments:\n        - first number to add\n"
        self.assertEquals(output, expectedoutput)

        # Test with only Types
        content = {'types': [{'fields': [{'required': 'false', 'type': 'string', 'name': 'ca'}], 'name': 'testtype'}]}
        output = panh.render_template(content, "component-test")
        print output
        expectedoutput = "\n### Types\n\n - `/software/component-test/testtype`\n    - `/software/component-test/testtype/ca`\n\
        - Optional\n        - Type: string\n"
        self.assertEquals(output, expectedoutput)

    def test_get_content_from_pan(self):
        """Test get_content_from_pan function."""
        # Test with empty pan input file.
        self.assertEqual(panh.get_content_from_pan("test/testdata/pan_empty_input.pan"), {})

        expectedresult = {'functions':
                          [{'args': ['first number to add',
                                     'second number to add'],
                            'name': 'add',
                            'desc': 'simple addition of two numbers'}],
                          'types': [
                              {'fields': [
                                  {'range': '0..1',
                                   'required': 'true',
                                   'type': 'long',
                                   'name': 'debug',
                                   'desc': 'Test long.'},
                                  {'required': 'false',
                                   'type': 'string',
                                   'name': 'ca_dir',
                                   'desc': 'Test string'}],
                               'name': 'testtype',
                               'desc': 'test type.'}]}

        # Test with valid input.
        self.assertEqual(panh.get_content_from_pan("test/testdata/pan_annotated_schema.pan"), expectedresult)

    def test_markdown_from_pan(self):
        """Test markdown_from_pan function."""
        # Test valid input
        testdir = os.path.join(self.tmpdir, "testdata/target")
        testfile = os.path.join(testdir, "pan_annotated_schema.pan")
        os.makedirs(testdir)
        shutil.copy("test/testdata/pan_annotated_schema.pan", testfile)
        testoutput = panh.markdown_from_pan(testfile)
        print testoutput
        self.assertEqual(len(testoutput), 484)
        self.assertTrue("Types" in testoutput)
        self.assertTrue("Functions" in testoutput)

        # Test invalid input
        testdir = os.path.join(self.tmpdir, "testdata2/target")
        testfile = os.path.join(testdir, "pan_empty_input.pan")
        os.makedirs(testdir)
        shutil.copy("test/testdata/pan_empty_input.pan", testfile)
        self.assertIsNone(panh.markdown_from_pan(testfile))

    def test_get_basename(self):
        """Test get_basename function."""
        test = "/tmp/test/src/modules-core/ncm-useraccess/target/pan/components/useraccess/config-common.pan"
        self.assertTrue(panh.get_basename(test), "xxx")

    def suite(self):
        """Return all the testcases in this module."""
        return TestLoader().loadTestsFromTestCase(PanHandlerTest)

if __name__ == '__main__':
    main()
