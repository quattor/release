#!/usr/bin/env python
"""
Basic setup.py for building the documentation-builder.

@author: Wouter Depypere
"""

from setuptools import setup, find_packages

if __name__ == '__main__':
    setup(
        name = 'documentation-builder',
        description = 'Documentation Builder for Quattor',
        url='https://github.com/quattor/release/src/documentation_builder/',
        version = '0.0.1',
        author = 'Wouter Depypere',
        author_email = 'wouter.depypere@ugent.be',
        packages = find_packages('lib'),
        package_dir={'':'lib'},
        scripts=['bin/quattor-documentation-builder', 'bin/build-quattor-documentation.sh'],
        install_requires = [
            'vsc-utils',
            'vsc-base',
            'Template-Python',
            'lxml',
        ],
        test_suite = "test",
        tests_require = ["prospector"],
        include_package_data=True,
    )
