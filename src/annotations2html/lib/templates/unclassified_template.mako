<%!
  import tpldocutils
%>
<style>
${tpldocutils.styles()}
</style>

<%inherit file="base.html"/>
<%def name="head_title()">
${title}
</%def>
<%include file="nav.mako" args="navigation=navigation, section=section"/>
<div id='content-column'>
<div class='module primary'>
<h2 class='code'>${title}</h2>
</div>

% if xml.findall("{%s}synopsis" % ns):
<div class='module secondary ltgray'>
<h2>Synopsis</h2>
<blockquote class='pan'>
${tpldocutils.pan_markup(xml.findtext("{%s}synopsis" % ns))}
</blockquote>
</div>
% endif

% if xml.findtext("{%s}desc" % ns):
<div class='module secondary ltgray'>
<h2>Description</h2>
<p>
${tpldocutils.annotation_markup(xml.findtext("{%s}desc" % ns))}
</div>
% endif

% if xml.findall("{%s}function" % ns):
<div class='module secondary ltgray'>
<h2>Functions</h2>
<dl compact='compact'>
% for fn in sorted(xml.findall("{%s}function" % ns), key=lambda x: x.attrib['name'].lower()):
<dt>${fn.attrib['name']}()</dt>
% if 'desc' in fn.attrib:
<dd>${fn.attrib['desc'] | h}</dd>
% endif
% endfor
</dl>
</div>
% endif

% if xml.findall("{%s}variable" % ns):
<div class='module secondary ltgray'>
<h2>Global Variables</h2>
<dl compact='compact'>
% for var in sorted(xml.findall("{%s}variable" % ns), key=lambda x: x.attrib['name'].lower()):
<dt>${var.attrib['name'] | h}</dt>
% if 'desc' in var.attrib:
<dd>${var.attrib['desc'] | h}</dd>
% endif
% endfor
</dl>
</div>
% endif

% if xml.findall("{%s}see-also" % ns) or len(index[tplname]) > 1:
<div class='module secondary ltgray'>
<h2>See Also</h2>
<ul>
% if xml.findall("{%s}see-also" % ns):
<li>${tpldocutils.annotation_markup(xml.findtext("{%s}see-also" % ns))}
% endif
% if len(index[tplname]) > 1:
% for alt, text in sorted(index[tplname]):
% if alt != htmlname:
<li><a href='${alt}'>${text}</a></li>
% endif
% endfor
% endif
</ul>
</div>
% endif

<div class='module secondary ltgray'>
<h2>Template</h2>

${tpldocutils.pan_markup(source)}

</div>

% if errors:
<div class='module secondary red'>
<h2>Errors/Warnings</h2>
<ul>
% for (err, lines, text) in errors:
<li><b>${err | h}</b>: ${lines}<pre class='error'>${text | h}</pre></li>
% endfor
</ul>
</div>
% endif
</div>
