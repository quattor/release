#!/usr/bin/env python2

import os
import re
import sys
import errno
import tempfile
from subprocess import Popen, PIPE
import shutil
import time
from time import ctime
import argparse
import logging
from collections import defaultdict
from operator import itemgetter

from lxml import etree
from mako.lookup import TemplateLookup
from mako import exceptions

BINDIR = os.path.dirname(os.path.realpath(sys.argv[0]))
sys.path.append(os.path.join(BINDIR, "..", "lib", "python"))

log = logging.getLogger("annotations2html")

template_re = re.compile(r"^\s*(?:(?:object|structure|declaration|unique)\s+)*"
                         r"template\s+(\S+)\s*;")

panc_annotations = "panc-annotations"

# TEMPLATES_BYNAME is an indexed keyed by template name
# (the template name may be ambiguous due to LOADPATH)
TEMPLATES_BYNAME = defaultdict(list)

# create some namespaced tagnames
ns = "http://quattor.org/pan/annotations"
tags = dict()
for t in ["desc", "section"]:
    tags[t] = "{%s}%s" % (ns, t)


def is_template(name):
    if name.endswith((".pan", ".tpl")):
        return True
    return False


def parse_panc_errors(text):
    ret = defaultdict(list)
    filename = None
    errortxt = None
    lines = None
    output = list()

    relativeize = re.compile(os.getcwd() + "/(.*)\\.((pan)|(tpl))")
    error = re.compile(r'(?P<err>[\w\s]+) \[(?P<file>.*):(?P<lines>[0-9.-]+)\]$')
    for line in text.split("\n"):
        m = error.match(line)
        if m:
            # flush out old error
            if filename is not None:
                ret[filename].append([errortxt, lines, output])

            parts = m.groupdict()
            filename = parts["file"]
            # filename emmitted by panc is a full absolute pathname.
            # we want to work out a normalized name
            filename = os.path.relpath(filename, os.getcwd())
            errortxt = parts["err"]
            lines = parts["lines"]
            output = list()
        else:
            output.append(line)

    # flush out old error
    if filename is not None:
        ret[filename].append([errortxt, lines, output])

    return ret


def render_one(outfile, transform, args):
    try:
        result = transform.render(**args)
    except:
        print exceptions.text_error_template().render()
    log.debug("writing %s", outfile)
    with open(outfile, 'w') as fd:
        fd.write(result)


def annotate(templates, index, state, base_path, outdir, render_at_end):
    if not templates:
        return

    # Get a temporary directory. panc annotations
    # will be dumped into directory names corresponding
    # to the template namespace, so we need a small tree
    tmpdir = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(tmpdir, base_path))
    except OSError as exc:
        if exc.errno == errno.EEXIST:
            pass
        else:
            raise

    deferred = []

    try:
        # Run "panc" to get the annotation data
        args = [panc_annotations, "--output-dir", tmpdir]
        args.extend([os.path.join(base_path, tpl) for tpl in templates])
        log.info("invoking %s", " ".join(args))

        # Make sure output from pan is not mixed with output from this script
        sys.stdout.flush()

        p = Popen(args, stderr=PIPE, stdout=PIPE)
        out, err = p.communicate()
        log.info("command returned %d", p.returncode)
        log.debug("command stdout:\n%s", out)
        log.debug("command stderr:\n%s", err)

        errors = parse_panc_errors(out)

        important = "documentation.annotation.xml"
        # And now parse all the annotations that we received
        for root, dirs, files in os.walk(tmpdir, topdown=True):
            files.sort()
            try:
                # Try and move the important file to the front,
                # but it may not exist. If we can't never mind -
                # just process the sorted list.
                files.remove(important)
                files.insert(0, important)
            except:
                pass

            relpath = os.path.relpath(root, tmpdir)
            if relpath not in state:
                state[relpath] = state[os.path.dirname(relpath)].copy()

            for file in files:
                if not file.endswith(".xml"):
                    continue

                log.debug("parsing %s/%s", relpath, file)
                # Create a filename to dump the HTML output
                htmlname = os.path.join(relpath, file)
                htmlname = re.sub(r'\.xml$', '.html', htmlname)
                htmlname = re.sub(r'/', '.', htmlname)
                outfile = os.path.join(outdir, htmlname)

                xml = etree.parse(os.path.join(root, file))

                # Work out what section we're in - we allow
                # the input templates to modify this (so that you
                # can have a documentation.tpl in a directory
                # that sets the section name for all subsequent
                # templates)
                section = xml.findtext("{%s}section" % ns)
                if section is not None:
                    log.info("found section %s for path %s", section, relpath)
                    state[relpath]['section'] = section
                section = state[relpath]['section']

                # Generate some text representing the template itself
                source = file[0:-len(".annotation.xml")]
                tplname = os.path.join(relpath, source)

                myerrors = None
                errname = os.path.join(relpath, file)
                errname = errname[0:-len(".annotation.xml")]
                if errname in errors:
                    myerrors = errors[errname]

                mtime = ctime(os.stat(tplname).st_mtime)
                sourcefd = open(tplname, "r")
                tplsource = fix_unicode(sourcefd.read())

                tnode = xml.getroot()
                # The source-range will provide the pointer to the template
                if tnode is not None and 'source-range' in tnode.attrib:
                    srange = tnode.attrib['source-range']
                    lines = tplsource.split("\n")
                    (start, end) = srange.split('-', 2)
                    (sline, schar) = start.split('.', 2)
                    (eline, echar) = end.split('.', 2)
                    declaration = "\n".join(lines[int(sline) - 1:int(eline)])
                    m = re.search(r'template ([^;]*)', declaration)
                    if m:
                        # We modify the template name to allow for loadpath
                        tplname = m.group(1)

                if base_path != "":
                    entry_title = "%s (%s)" % (tplname, base_path)
                else:
                    entry_title = "%s (top level)" % tplname

                TEMPLATES_BYNAME[tplname].append((htmlname, entry_title))
                if len(TEMPLATES_BYNAME[tplname]) > 1:
                    TEMPLATES_BYNAME[tplname].sort()

                title = xml.findtext("{%s}title" % ns)
                if title is None:
                    title = tplname

                content = None
                # Indexing
                for fn in xml.findall("{%s}function" % ns):
                    index_add(index, "functions", "%s()" % fn.attrib['name'],
                              htmlname, entry_title)
                    content = True
                for var in xml.findall("{%s}variable" % ns):
                    index_add(index, "global variables", var.attrib['name'],
                              htmlname, entry_title)
                    content = True

                index_add(index, section, title, htmlname, entry_title)

                if section not in transformers:
                    transformers[section] = get_transform(section + "_template")
                transform = transformers[section]

                # This is incredibly memory hungry, but we're going to
                # just stash things in memory and then render at the end,
                # allowing files to contain cross-referencing indexes.
                # if memory usage gets too bad, then we can drop the
                # cross-referencing within specific files and render as we
                # go...
                context = {'title': title,
                           'tplname': tplname,
                            'htmlname': htmlname,
                            'navigation': index,
                            'source': tplsource,
                            'errors': myerrors,
                            'section': section,
                            'mtime': mtime,
                            'xml': xml,
                            'ns': ns,
                            'state': state[relpath],
                            'index': TEMPLATES_BYNAME}
                if render_at_end:
                    deferred.append((outfile, transform, context))
                else:
                    render_one(outfile, transform, context)

    finally:
        shutil.rmtree(tmpdir)

    return deferred


def fix_unicode(value):
    """ Remove unusable characters from unreliable data sources """
    if value is None:
        return value
    try:
        unicode(value, "ascii")
    except UnicodeError:
        return unicode(value, "utf-8", "replace")
    else:
        return value


def index_add(index, section, title, href, text):
    if section not in index:
        index[section] = dict()
    if title not in index[section]:
        index[section][title] = []
    index[section][title].append((href, text))
    if len(index[section][title]) > 1:
        index[section][title].sort(key=itemgetter(0))


def build_toplevels(out, index):
    log.info("building index files")

    for section in index.keys():
        log.info("building %s", section)
        idxbody = []

        s = section.capitalize()
        if not s.endswith('s'):
            if s.endswith('y'):
                s = "%sies" % s[:-1]
            else:
                s = "%ss" % s
        if s == "Unclassifieds":
            s = "Unclassified Templates"

        if section in index:
            titles = index[section].keys()
            titles.sort(key=lambda x: x.lower())
            for title in titles:
                hreflist = ",<br>".join("<a href='%s'>%s</a>" % (href, text)
                                     for (href, text) in index[section][title])
                if len(index[section][title]) == 1 and \
                   index[section][title][0][1] == title:
                    idxbody.append("<dt>%s</dt><dd></dd>" % hreflist)
                else:
                    idxbody.append("<dt>%s</dt><dd>%s</dd>" % (title, hreflist))

        safe = section
        for x in [" ", "/", "\\"]:
            safe = safe.replace(x, "_")
        transform = get_transform(safe, default="toplevel")
        context = {'body': idxbody,
                   'navigation': index,
                   'section': section,
                   'mtime': time.asctime(),
                   'title': s}

        outfile = os.path.join(out, "%s.html" % safe)
        result = None
        result = transform.render(**context)
        log.debug("writing %s", outfile)
        with open(outfile, 'w') as fd:
            fd.write(result)


def get_transform(section, default='unclassified_template'):
    if section.find("/") >= 0:
        raise Exception("Sections cannot be hierarchial")
    f = os.path.join(BINDIR, "..", "lib", "templates", "%s.mako" % section)
    if not os.path.exists(f):
        section = default

    lookup = TemplateLookup([os.path.join(BINDIR, "..", "lib", "templates")],
                            output_encoding='utf-8', encoding_errors='replace')
    tpl = lookup.get_template("%s.mako" % section)
    return tpl


transformers = dict()
transformers["unclassified"] = get_transform("unclassified")


def detect_template_basedir(top, filename):
    # If top = "/path", filename = "/path/a/b/c.tpl", and it starts with
    # "template b/c;", then we want to return (a, b/c.tpl)
    template_name = None
    relpath, ext = os.path.splitext(os.path.relpath(filename, top))
    with open(filename, "r") as fd:
        for line in fd:
            res = template_re.match(line)
            if not res:
                continue
            template_name = res.group(1)
            break

    if template_name and (relpath == template_name or
                          relpath.endswith("/" + template_name)):
        if relpath == template_name:
            return ".", template_name + ext
        else:
            return relpath[:-len(template_name) - 1], template_name + ext
    else:
        # Either we failed to parse the template, or the template name was not
        # correct. The safe choice is to parse the template alone (well, at most
        # together with other templates in the same directory), and let panc
        # sort it out.
        return os.path.dirname(relpath), os.path.basename(relpath) + ext


def chunk_list(list_, chunk_size):
    for i in xrange(0, len(list_), chunk_size):
        yield list_[i:i + chunk_size]


# Usage: %prog [options] <SOURCE> <OUTPUT>
# e.g. to read templates starting at /my/templates
# and to write them out into /var/htdocs/templates, you would
# %prog /my/templates /var/htdocs/templates
#
# An index.html file, and a set of .html files corresponding
# to template names will be created. You should have a
# css file called "annotations.css" in the output directory to
# get useful HTML viewing.

# This processes single directories at a time. Which incurs
# a hefty penalty in firing off java each time, however we
# can't really do this "in aggregate" across all directories
# because the annotation output filename is based on the
# template name, and that is not unique (there may be multiple
# template names the same in different loadpath contexts)
def main():
    parser = argparse.ArgumentParser(description="Generate template documentation")
    parser.add_argument("-d", "--debug", dest="debug", action="count",
                        help="Extra output. Specify twice for even more")
    parser.add_argument("-j", "--java", dest="java", metavar='JAVA_HOME',
                        help="Location of the JRE")
    parser.add_argument("--norender_at_end", dest="render_at_end",
                        action="store_false", default=True,
                        help="Render immediately. Reduces memory usage, but "
                             "breaks cross referencing")
    parser.add_argument("source", help="Directory where the templates can be found")
    parser.add_argument("output", help="Output directory")
    args = parser.parse_args()

    if args.java is not None:
        os.environ["JAVA_HOME"] = args.java

    if args.debug > 1:
        logging.basicConfig(level=logging.DEBUG)
    elif args.debug == 1:
        logging.basicConfig(level=logging.INFO)
    else:
        logging.basicConfig(level=logging.WARNING)

    top = args.source
    # If the chdir fails, the exception is just what we want.
    os.chdir(top)

    out = args.output
    if not os.path.exists(out):
        os.makedirs(out)

    # Always copy across the latest CSS
    css = os.path.join(BINDIR, "..", "lib", "annotations.css")
    shutil.copyfile(css, os.path.join(out, "annotations.css"))

    log.warning("starting %s %s %s", sys.argv[0], top, out)

    index = dict()
    index['contents'] = dict()
    state = dict()
    state[""] = dict({'section': 'unclassified'})

    work_queue = []

    template_bases = defaultdict(list)

    for root, dirs, files in os.walk(top, topdown=True):
        # Make sure we don't descend into mgmt directories (e.g. .git)
        for i in range(len(dirs) - 1, -1, -1):
            if dirs[i].startswith("."):
                del dirs[i]
            if root == top and dirs[i] == 't':
                # 't' is considered to be a "test" directory - ignore it
                del dirs[i]

        for f in files:
            if not is_template(f):
                continue

            basedir, tplpath = detect_template_basedir(top, os.path.join(root, f))
            template_bases[basedir].append(tplpath)

    for relpath in sorted(template_bases.keys()):
        log.info("scanning templates relative to %s", relpath)
        tpls = template_bases[relpath]

        if relpath == ".":
            root = top
        else:
            root = os.path.join(top, relpath)

        for chunk in chunk_list(tpls, 1000):
            deferred = annotate(chunk, index, state, relpath, out,
                                args.render_at_end)
            if deferred:
                work_queue.extend(deferred)

    log.info("rendering html")
    for (outfile, transform, args) in work_queue:
        render_one(outfile, transform, args)

    build_toplevels(out, index)


if __name__ == '__main__':
    main()
