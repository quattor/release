"""Test module for builder.py."""

import sys
import os
import shutil
from tempfile import mkdtemp
from unittest import TestCase, main, TestLoader
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../lib')))  # noqa
from quattordocbuild import builder
from quattordocbuild import repo


class BuilderTest(TestCase):
    """Test class for builder.py."""

    def setUp(self):
        """Set up temp dir for tests."""
        self.tmpdir = mkdtemp()

    def tearDown(self):
        """Remove temp dir."""
        shutil.rmtree(self.tmpdir)

    def test_which(self):
        """Test which function."""
        self.assertFalse(builder.which('testtest1234'))
        self.assertTrue(builder.which('python'))

    def test_check_input(self):
        """Test check_input function."""
        self.assertFalse(builder.check_input("", ""))
        self.assertFalse(builder.check_input(self.tmpdir, ""))
        self.assertFalse(builder.check_input("/nonexistingdir", ""))
        self.assertTrue(builder.check_input(self.tmpdir, self.tmpdir))
        os.makedirs(os.path.join(self.tmpdir, "test"))
        self.assertTrue(builder.check_input(self.tmpdir, os.path.join(self.tmpdir, "test")))

    def test_check_commands(self):
        """Test check_commands function."""
        self.assertTrue(builder.check_commands(True))

    def test_build_site_structure(self):
        """Test build_site_structure function."""
        expected_response = {'CCM': {'Fetch_Download.rst': '# NAME\n\nEDG::WP4::CC'},
                             'components': {'aii_freeipa_schema.rst': 'Hello2',
                                            'fmonagent.rst': 'Hello',
                                            'profile_functions.rst': u'\n### Functions\n'}}

        file1 = repo.Sourcepage('Fetch\::Download', '/tmp/qdoc/src/CCM/target/doc/pod/EDG/WP4/CCM/Fetch/Download.pod', False, False)
        file1.rstcontent = '# NAME\n\nEDG::WP4::CC'
        file2 = repo.Sourcepage('profile\::functions', '/tmp/doc/src/configuration-modules-core/ncm-profile/target/pan/components/profile/functions.pan', False, False)
        file2.rstcontent = u'\n### Functions\n'
        file3 = repo.Sourcepage('fmonagent', '/tmp/doc/src/configuration-modules-core/ncm-fmonagent/target/doc/pod/NCM/Component/fmonagent.pod', False, False)
        file3.rstcontent = 'Hello'
        file4 = repo.Sourcepage('aii\::freeipa - schema', '/tmp/doc/src/configuration-modules-core/ncm-freeipa/target/pan/quattor/aii/freeipa/schema.pan', False, False)
        file4.rstcontent = 'Hello2'

        repo1 = repo.Repo('CCM', 'notimportant')
        repo1.sources = [file1, ]
        repo2 = repo.Repo('configuration-modules-core', 'notimportant')
        repo2.sources = [file2, file3, file4]
        self.assertEquals(builder.build_site_structure([repo1, repo2]), expected_response)

    def test_make_interlinks(self):
        """Test make_interlinks function."""
        # Replace one reference
        test_data = {'components-grid': {'fmonagent.rst': ''},
                     'components': {'icinga.rst': 'I refer to `fmonagent`.'}}
        expected = {'components-grid': {'fmonagent.rst': ''},
                    'components': {'icinga.rst': 'I refer to [fmonagent](../components-grid/fmonagent.rst).'}}
        self.assertEquals(builder.make_interlinks(test_data), expected)

        # Replace two references
        test_data = {'comps-gr': {'fmnt.rst': ''},
                     'comps': {'icinga.rst': 'refr `fmnt` and `fmnt`.'}}
        expected = {'comps-gr': {'fmnt.rst': ''},
                    'comps': {'icinga.rst': 'refr [fmnt](../comps-gr/fmnt.rst) and [fmnt](../comps-gr/fmnt.rst).'}}
        self.assertEquals(builder.make_interlinks(test_data), expected)

        # Replace ncm- reference
        test_data = {'components-grid': {'fmonagent.rst': ''},
                     'components': {'icinga.rst': 'I refer to `ncm-fmonagent`.'}}
        expected = {'components-grid': {'fmonagent.rst': ''},
                    'components': {'icinga.rst': 'I refer to [fmonagent](../components-grid/fmonagent.rst).'}}
        self.assertEquals(builder.make_interlinks(test_data), expected)

        # Replace newline reference
        test_data = {'components-grid': {'fmonagent.rst': ''},
                     'components': {'icinga.rst': 'I refer to \n`ncm-fmonagent`.'}}
        expected = {'components-grid': {'fmonagent.rst': ''},
                    'components': {'icinga.rst': 'I refer to \n[fmonagent](../components-grid/fmonagent.rst).'}}
        self.assertEquals(builder.make_interlinks(test_data), expected)

        # Replace linked wrong reference
        test_data = {'components-grid': {'fmonagent.rst': ''},
                     'components': {'icinga.rst': 'I refer \
to [NCM::Component::FreeIPA::Client](https://metacpan.org/pod/NCM::Component::FreeIPA::Client).',
                                    'FreeIPA::Client': 'Allo'}}
        expected = {'components-grid': {'fmonagent.rst': ''},
                    'components': {'icinga.rst': 'I refer to [FreeIPA::Client](../components/FreeIPA::Client).',
                                   'FreeIPA::Client': 'Allo'}}

        self.assertEquals(builder.make_interlinks(test_data), expected)

        # Don't replace in own page
        test_data = {'comps-grid': {'fmonagent.rst': 'ref to `fmonagent`.'},
                     'comps': {'icinga.rst': 'ref to `icinga` and `ncm-icinga`.'}}
        self.assertEquals(builder.make_interlinks(test_data), test_data)

    def test_write_site(self):
        """Test write_site function."""
        testinput = {'CCM': {'fetch::download.rst': '# NAME\n\nEDG::WP4::CC'},
                     'components': {'fmonagent.rst': 'Hello',
                                    'profile::functions.rst': u'\n### Functions\n'}}

        sitedir = os.path.join(self.tmpdir, "docs")
        builder.write_site(testinput, self.tmpdir, "docs")
        self.assertTrue(os.path.exists(os.path.join(sitedir, 'components')))
        self.assertTrue(os.path.exists(os.path.join(sitedir, 'components/profile::functions.rst')))
        self.assertTrue(os.path.exists(os.path.join(sitedir, 'components/fmonagent.rst')))
        self.assertTrue(os.path.exists(os.path.join(sitedir, 'CCM')))
        self.assertTrue(os.path.exists(os.path.join(sitedir, 'CCM/fetch::download.rst')))

    def suite(self):
        """Return all the testcases in this module."""
        return TestLoader().loadTestsFromTestCase(BuilderTest)


if __name__ == '__main__':
    main()
