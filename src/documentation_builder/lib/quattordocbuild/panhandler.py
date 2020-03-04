"""Handle pan files for documentation."""

import os
import re
import tempfile
import shutil
import jinja2
from vsc.utils import fancylogger
from vsc.utils.run import asyncloop
from lxml import etree

logger = fancylogger.getLogger()
namespace = "{http://quattor.org/pan/annotations}"


def rst_from_pan(panfile, title, path_prefix, guess_basename):
    """Make reStructuredText from a pan annotated file."""
    logger.info("Making rst from pan: %s.", panfile)
    content = get_content_from_pan(panfile)
    logger.debug(content)
    basename = ''
    if guess_basename:
        basename = get_basename(panfile)
    if path_prefix:
        basename = '%s%s/' % (path_prefix, basename)
    output = render_template(content, basename, title)
    if not output:
        output = None
    return output


def render_template(content, basename, title):
    """Render the template."""
    loader = jinja2.FileSystemLoader(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'jinja'))
    jenv = jinja2.Environment(loader=loader, trim_blocks=True, lstrip_blocks=True)
    template = jenv.get_template('pan.j2')
    output = template.render(content=content, basename=basename, title=title)
    return output


def get_content_from_pan(panfile):
    """Return the information of all types and functions from a pan annotated file."""
    content = {}
    tempdir = tempfile.mkdtemp()
    directory, filename = os.path.split(panfile)
    built = build_annotations(filename, directory, tempdir)
    if built:
        xmlroot = validate_annotations(os.path.join(tempdir, "%s.annotation.xml" % filename))
        if xmlroot is not None:
            types, functions, variables = get_types_and_functions(xmlroot)
            if types is not None:
                content['types'] = []
                for ptype in types:
                    content['types'].append(parse_type(ptype))

            if functions is not None:
                content['functions'] = []
                for function in functions:
                    content['functions'].append(parse_function(function))

            if variables is not None:
                content['variables'] = []
                for variable in variables:
                    content['variables'].append(parse_variable(variable))
    shutil.rmtree(tempdir)
    return content


def build_annotations(pfile, basedir, outputdir):
    """Build pan annotations."""
    panccommand = ["panc-annotations", "--output-dir", outputdir, "--base-dir", basedir]
    panccommand.append(pfile)
    logger.debug("Running %s.", panccommand)
    errc, output = output = asyncloop(panccommand)
    logger.debug(output)
    if errc == 0 and os.path.exists(os.path.join(outputdir, "%s.annotation.xml" % pfile)):
        return True
    else:
        logger.warning("Something went wrong running '%s'.", panccommand)
        return False


def validate_annotations(pfile):
    """
    Check if a pan annotations file is usable.

    e.g. XML is parsable and the root element is not empty.
    If it is usable, return the xml root element.
    """
    xml = etree.parse(pfile)
    root = xml.getroot()

    if not len(root):
        logger.debug("%s is empty, skipping it.", pfile)
        root = None

    return root


def get_types_and_functions(root):
    """Return a list of types and functions from a root element."""
    types = root.findall('%stype' % namespace)
    functions = root.findall('%sfunction' % namespace)
    variables = root.findall('%svariable' % namespace)

    logger.debug("types: %s", types)
    logger.debug("functions: %s", functions)
    logger.debug("variables: %s", variables)

    if not types and not functions and not variables:
        logger.debug("%s has no usable content, skipping it.", root)
        return None, None, None

    return types, functions, variables


def find_description(element):
    """Search for the desc tag, even if it is in documentation tag."""
    desc = element.find("./%sdocumentation/%sdesc" % (namespace, namespace))
    if desc is None:
        desc = element.find("./%sdesc" % namespace)
    return desc

def cleanup_description(desc):
    """Clean up a multiline description."""
    return " ".join(desc.replace('\n', ' ').replace('\r', ' ').split())

def parse_type(ptype):
    """Parse a type from an XML Element Tree."""
    typeinfo = {}
    typeinfo['name'] = ptype.get('name')
    desc = find_description(ptype)
    if desc is not None:
        typeinfo['desc'] = cleanup_description(desc.text)

    typeinfo['fields'] = []

    for field in ptype.findall(".//%sfield" % namespace):
        fieldinfo = {}
        fieldinfo['name'] = field.get('name')
        desc = find_description(field)
        if desc is not None:
            fieldinfo['desc'] = cleanup_description(desc.text)

        fieldinfo['required'] = field.get('required')
        basetype = field.find(".//%sbasetype" % namespace)
        fieldtype = basetype.get('name')
        fieldinfo['type'] = fieldtype
        if fieldtype == "long" and basetype.get('range'):
            fieldinfo['range'] = basetype.get('range')

        fielddefault = field.find(".//%sdefault" % namespace)
        if fielddefault is not None:
            fielddeftext = fielddefault.get('text')
            if '`' in fielddeftext:
                fielddeftext = fielddeftext.replace('`', '\`')

            if fielddeftext.endswith('_'):
                fielddeftext = fielddeftext.replace('_', '\_')

            fieldinfo['default'] = fielddeftext
        typeinfo['fields'].append(fieldinfo)

    return typeinfo


def parse_function(function):
    """Parse a function from an XML Element Tree."""
    functinfo = {}
    functinfo['name'] = function.get('name')
    desc = find_description(function)
    if desc is not None:
        functinfo['desc'] = cleanup_description(desc.text)
    functinfo['args'] = []
    for arg in function.findall(".//%sarg" % namespace):
        functinfo['args'].append(cleanup_description(arg.text))

    return functinfo

def parse_variable(pvar):
    """Parse a type from an XML Element Tree."""
    varinfo = {}
    varinfo['name'] = pvar.get('name')
    desc = find_description(pvar)
    if desc is not None:
        varinfo['desc'] = cleanup_description(desc.text)

    vardefault = pvar.get('default')
    if vardefault is not None:
        varinfo['default'] = vardefault.get('text')

    varvalues = pvar.find(".//%svalues" % namespace)
    if varvalues is not None:
        varinfo['varvalues'] = varvalues.get('text')

    return varinfo


def get_basename(path):
    """Return a base name from a path and regular expression."""
    regex = r".*/(.*?)/target/.*"
    result = re.search(regex, path)
    if result:
        result = result.group(1)
    else:
        logger.error("failed to find basename from path %s", path)
        return None
    if "ncm-" in result:
        result = result.replace("ncm-", "")

    return result
