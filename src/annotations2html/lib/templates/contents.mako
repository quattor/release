<%
  import time
  import socket
  import sys
  import os
%>
<%inherit file="base.html"/>
<%def name="head_title()">
Quattor Templates
</%def>
<%include file="nav.mako" args="navigation=navigation, section=section"/>
<div id='content-column'>
<div class='module primary'>
<h2>${title}</h2>
<p>These pages provide documentation for Quattor templates. The documentation is generated from annotations within the templates.</p>
<div class='panel'>
<p>This content was generated at ${time.ctime()} on the host <code>${socket.gethostname()}</code>.<br>
The command run was: <code>${" ".join(sys.argv)}</code>.</p>
%if "AUTO_JOB_NAME" in os.environ:
<p>
The content was generated via the autosys job ${os.environ["AUTO_JOB_NAME"]}
from the ${os.environ["AUTOSERV"]} instance.
</p>
%endif
</div>
</div>
</div>
