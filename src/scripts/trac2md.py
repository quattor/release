#!/usr/bin/python

"""
Script to convert a Tracwiki page to Jekyll markdown.

Wrapper over pandoc to convert a tracwiki file to a Jekyll markdown file.
The problem is that pandoc doesn't support tracwiki as an input syntax.
This script converts the tracwiki file into a GitHub markdown file and then
invokes pandoc to convert from GitHub markdown to pure (Jekyll) markdown.
"""

import os
import sys
import re
import argparse
import subprocess

HEADING_1_PATTERN = re.compile(r'^=(?P<title>.*)\s+=\s*$')
HEADING_2_PATTERN = re.compile(r'^==(?P<title>.*)\s+==\s*$')
HEADING_3_PATTERN = re.compile(r'^===(?P<title>.*)\s+===\s*$')
LINK_PATTERN = re.compile(r'\[(?P<url>https?://.*)\s+(?P<text>\w+)\]')
MACRO_PATTERN = re.compile(r'^\s*\[\[.*\]\]\s*')
CODE_PATTERN = re.compile(r'\{\{\{|\}\}\}')

def main():

    parser = argparse.ArgumentParser(description='Trac permissions update')
    parser.add_argument('--debug', action="store_true", default=False, help='Debug mode')
    parser.add_argument('--frontmatter', action="store", default='', help='File containing frontmatter header')
    parser.add_argument('trac_files', metavar='trac_files', nargs='*', default=[], help='Tracwiki files to convert')
    args = parser.parse_args()

    # Read frontmatter file if specified

    if args.frontmatter:
        try:
            with open(args.frontmatter, 'r') as fm_f:
                frontmatter = list(fm_f)
        except Exception, e:
            print e
            print "Failed to read frontmatter file (%s)" % args.frontmatter
    else:
        frontmatter = list()


    # Main loop: process each file specified

    for file in args.trac_files:
        md_file = '%s.md' % re.sub(r'\.trac\w*$', r'', file)
        tmp_file = '%s.tmp' % md_file
        print "Converting Tracwiki file %s into MD file %s" % (file, md_file)

        try:
            md_f = open(tmp_file,'w')
        except Exception, e:
            print e
            print "Error creating MD file %s" % md_file
            return 1

        # Convert the Tracwiki file into a GitHub markdown compatible file

        try:
            with open(file, 'r') as trac_f:
                for line in trac_f:
                    line= line.rstrip()
                    if not MACRO_PATTERN.match(line):
                        line = HEADING_3_PATTERN.sub(r'### \g<title>', line)
                        line = HEADING_2_PATTERN.sub(r'## \g<title>', line)
                        line = HEADING_1_PATTERN.sub(r'# \g<title>', line)
                        line = LINK_PATTERN.sub(r'[\g<text>](\g<url>)', line)
                        line = CODE_PATTERN.sub(r'```', line)
                        md_f.write('%s\n' % line)

        except IOError, e:
            print e
            print "Error opening Tracwiki file %s. Skipping it." % file
            continue

        md_f.close()

        # Execute pandoc to convert the GitHub markdown file produced above into
        # a Jekyll markdown/kramdown file

        try:
            pandoc_cmd = 'pandoc -f markdown_github -t markdown --atx -o %s %s' % (md_file, tmp_file)
            subprocess.call(pandoc_cmd, shell=True)
        except Exception, e:
            print e
            print "Error converting %s to markdown" % file

        # Insert frontmatter at the beginning of the file if specified

        if frontmatter:
            try:
                with open(md_file, 'r') as md_f:
                    md_contents = list(md_f)
            except Exception, e:
                print e
                print "Error reading MD file %s to add frontmatter" % md_file
            try:
                with open(md_file, 'w') as md_f:
                    for line in frontmatter+md_contents:
                        line = line.rstrip()
                        md_f.write('%s\n' % line)
            except Exception, e:
                print e
                print "Error updating MD file %s to add frontmatter" % md_file

        # Remove temporary file, except if --debug
        if not args.debug:
            os.remove(tmp_file)

if __name__ == '__main__':
    sys.exit(main())