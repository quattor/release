<%inherit file="base.html"/>
<%def name="head_title()">
${title}
</%def>
<%include file="nav.mako" args="navigation=navigation, section=section"/>
<div id='content-column'>
<div class='module primary'>
<h2>${title}</h2>

<dl class='code'>
%for li in body:
${li}
%endfor
</dl>
</div>
</div>
