<div id='nav' role='navigation'>
<h2>Template Sections</h2>
<ul class='nav nav-tabs'>
%for idxsection in sorted(navigation.keys()):
<%
  safe = idxsection
  for x in [" ", "/", "\\"]:
    safe = safe.replace(x, "_")
  endfor
%>
%  if section == idxsection:
    <li role='presentation' class='active'><a href='${safe}.html'>${idxsection.title()}</a></li>
%  else:
    <li role='presentation'><a href='${safe}.html'>${idxsection.title()}</a></li>
%  endif
%endfor
</ul>
</div>
