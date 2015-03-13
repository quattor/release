import re

from pygments import highlight
from pygments.formatters import HtmlFormatter
from panlexer import PanLexer

links = re.compile(r'\[(((https?)|(ftp))://.*)\]')
lexer = PanLexer()
formatter = HtmlFormatter(linenos=False, cssclass="pan")


def styles():
    return formatter.get_style_defs('.pan')


def pan_markup(code):
    return highlight(code, lexer, formatter)


def annotation_markup(text):
    text = text.replace("&", "&amp;")
    text = text.replace(">", "&gt;")
    text = text.replace("<", "&lt;")
    text = text.replace("\n\n", "<p>")
    text = links.sub("<a href='\\1'>\\1</a>", text)
    return text
