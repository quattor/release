"""Handle pan files for documentation."""

import os
import re
import tempfile
import shutil
from template import Template, TemplateException
from vsc.utils import fancylogger
from vsc.utils.run import run_asyncloop
from lxml import etree

logger = fancylogger.getLogger()
namespace = "{http://quattor.org/pan/annotations}"


def markdown_from_pan(panfile):
    """Make markdown from a pan annotated file."""
    logger.info("Making markdown from pan: %s." % panfile)
    content = get_content_from_pan(panfile)
    basename = get_basename(panfile)
    output = render_template(content, basename)
    if len(output) == 0:
        return None
    else:
        return output


def render_template(content, basename):
    """Render the jinja template."""
    try:
        name = 'pan.tt'
        template = Template({'INCLUDE_PATH': os.path.join(os.path.dirname(__file__), 'tt')})
        output = template.process(name, {'content': content, 'basename': basename})
    except TemplateException as e:
        msg = "Failed to render template %s with data %s: %s." % (name, content, e)
        logger.error(msg)
        raise TemplateException('render', msg)
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
            types, functions = get_types_and_functions(xmlroot)
            if types is not None:
                content['types'] = []
                for type in types:
                    content['types'].append(parse_type(type))

            if functions is not None:
                content['functions'] = []
                for function in functions:
                    content['functions'].append(parse_function(function))
    shutil.rmtree(tempdir)
    return content


def build_annotations(file, basedir, outputdir):
    """Build pan annotations."""
    panccommand = ["panc-annotations", "--output-dir", outputdir, "--base-dir", basedir]
    panccommand.append(file)
    logger.debug("Running %s." % panccommand)
    ec, output = output = run_asyncloop(panccommand)
    logger.debug(output)
    if ec == 0 and os.path.exists(os.path.join(outputdir, "%s.annotation.xml" % file)):
        return True
    else:
        logger.warning("Something went wrong running '%s'." % panccommand)
        return False


def validate_annotations(file):
    """
    Check if a pan annotations file is usable.

    e.g. XML is parsable and the root element is not empty.
    If it is usable, return the xml root element.
    """
    xml = etree.parse(file)
    root = xml.getroot()

    if len(root) == 0:
        logger.debug("%s is empty, skipping it." % file)
        return None
    else:
        return root


def get_types_and_functions(root):
    """Return a list of types and functions from a root element."""
    types = root.findall('%stype' % namespace)
    functions = root.findall('%sfunction' % namespace)

    logger.debug(types)
    logger.debug(functions)

    if len(types) == 0 and len(functions) == 0:
        logger.debug("%s has no usable content, skipping it." % file)
        return None, None

    return types, functions


def find_description(element):
    """Search for the desc tag, even if it is in documentation tag."""
    desc = element.find("./%sdocumentation/%sdesc" % (namespace, namespace))
    if desc is None:
        desc = element.find("./%sdesc" % namespace)
    return desc


def parse_type(type):
    """Parse a type from an XML Element Tree."""
    typeinfo = {}
    typeinfo['name'] = type.get('name')
    desc = find_description(type)
    if desc is not None:
        typeinfo['desc'] = desc.text

    typeinfo['fields'] = []

    for field in type.findall(".//%sfield" % namespace):
        fieldinfo = {}
        fieldinfo['name'] = field.get('name')
        desc = find_description(field)
        if desc is not None:
            fieldinfo['desc'] = desc.text

        fieldinfo['required'] = field.get('required')
        basetype = field.find(".//%sbasetype" % namespace)
        fieldtype = basetype.get('name')
        fieldinfo['type'] = fieldtype
        if fieldtype == "long" and basetype.get('range'):
            fieldinfo['range'] = basetype.get('range')

        typeinfo['fields'].append(fieldinfo)

    return typeinfo


def parse_function(function):
    """Parse a function from an XML Element Tree."""
    functinfo = {}
    functinfo['name'] = function.get('name')
    desc = find_description(function)
    if desc is not None:
        functinfo['desc'] = desc.text
    functinfo['args'] = []
    for arg in function.findall(".//%sarg" % namespace):
        functinfo['args'].append(arg.text)

    return functinfo


def get_basename(path):
    """Return a base name from a path and regular expression."""
    regex = ".*/(.*?)/target/.*"
    result = re.search(regex, path)
    result = result.group(1)
    if "ncm-" in result:
        result = result.replace("ncm-", "")

    return result
