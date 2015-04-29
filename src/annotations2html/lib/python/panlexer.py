from pygments.lexer import RegexLexer, bygroups, include
from pygments.token import *


class PanLexer(RegexLexer):
    name = 'Pan'
    aliases = ['pan']
    filenames = ['*.pan', '*.tpl']

    tokens = {
        'root': [
            (r'\s+', Text),
            (r'\#.*$', Comment.Single),
            (r'(unique\b\s*)?((structure|object)\b\s*)?template\b\s*', Keyword, 'templatename'),
            (r'(function)((?:\s|\\\s)+)', bygroups(Keyword, Text), 'funcname'),
            (r'\@\(.*\)', Comment.Single),
            (r'\@\{', Comment.Multiline, 'annotationbrace'),
            (r'\@\(', Comment.Multiline, 'annotationbracket'),
            include('numbers'),
            (r"'(\\\\|\\'|[^'])*'", String),
            (r'"(\\\\|\\"|[^"])*"', String),
            include('keywords'),
            include('autovars'),
            include('builtins'),
            (r'(\[\]|<<|>>|>=|<=|!=|\?=|&&?|\|\|)', Operator),
            (r'[-+/*%=<>&^|!\\~]=?', Operator),
            (r'[\(\)\[\];,<>/\?\{\}]', Punctuation),
            (r'<<([\'"]?)([a-zA-Z_][a-zA-Z0-9_]*)\1;?\n.*?\n\2\n', String.Heredoc),
            (r'([a-zA-Z_][a-zA-Z0-9_]*)(\s*)(\()', bygroups(Name.Function, Text, Operator)),
            (r'[a-zA-Z_][a-zA-Z0-9_]*', Name),
        ],
        'annotationbrace': [
            (r'[^\}]+', Comment.Multiline),
            (r'\}', Comment.Multiline, '#pop'),
        ],
        'annotationbracket': [
            (r'[^\)]+', Comment.Multiline),
            (r'\)', Comment.Multiline, '#pop'),
        ],
        'templatename': [
            (r'[a-zA-Z_][\w_/-]*', Name.Namespace, '#pop')
        ],
        'funcname': [
            ('[a-zA-Z_][a-zA-Z0-9_]*', Name.Function, '#pop')
        ],
        'keywords': [
            (r'(if|for|with|else|type|bind|while|valid|unique|object|foreach|template|function|structure|extensible|declaration)\b', Keyword.Reserved),
            (r'(prefix|include)\b', Keyword.Namespace),
            (r'(final|variable)\b', Keyword.Declaration),
            (r'(undef|null|true|false)\b', Literal),
            (r'(boolean|long|double|string)\b', Keyword.Type)
        ],
        'autovars': [
            (r'(OBJECT|SELF|FUNCTION|TEMPLATE|LOADPATH|OBJECT|ARGC|ARGV)\b', Name.Variable),
        ],
        'builtins': [
            (r'(append|prepend|first|next|delete|exists|return|nlist|list|is_boolean|is_defined|is_double|is_long|is_nlist|is_list|is_null|is_number|is_property|'
             r'is_resource|is_string|value|error|length|match|matches|path_exists|to_lowercase|to_uppercase|to_string|to_boolean|to_long|to_double|'
             r'base64_encode|base64_decode|escape|unescape|key|merge|substr|replace|split|splice|index|clone|create|if_exists|format|deprecated|digest|'
             r'file_contents|debug|traceback)\b', Name.Builtin),
        ],
        'numbers': [
            (r'(\d+\.\d*|\d*\.\d+)([eE][+-]?[0-9]+)?', Number.Float),
            (r'\d+[eE][+-]?[0-9]+', Number.Float),
            (r'0\d+', Number.Oct),
            (r'0[xX][a-fA-F0-9]+', Number.Hex),
            (r'\d+L', Number.Integer.Long),
            (r'\d+', Number.Integer)
        ],
    }
