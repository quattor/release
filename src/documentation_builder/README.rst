Documentation-builder
---------------------

Documentation builder for the Quattor repositories.

::
 $ quattor-documentation-builder --help
 Usage: quattor-documentation-builder [options]


  Documentation-builder generates markdown documentation.

  It get this from:
   - configuration-modules-core perl documentation
   - configuration-modules-grid perl documentation
   - CAF perl documentation
   - CCM perl documentation
   - schema pan annotations
   and creates a index for the website on http://quattor.org.
  @author: Wouter Depypere (Ghent University)

 Options:
   -h, --shorthelp       show short help message and exit
   -H OUTPUT_FORMAT, --help=OUTPUT_FORMAT
                         show full help message and exit
   --confighelp          show help as annotated configfile

  Main options (configfile section MAIN):
    -p, --codify_paths  Put paths inside code tags. (def True)
    -i INDEX_NAME, --index_name=INDEX_NAME
                        Filename for the index/toc for the components. (def mkdocs.yml)
    -c, --maven_compile
                        Execute a maven clean and maven compile before generating the documentation. (def False)
    -m MODULES_LOCATION, --modules_location=MODULES_LOCATION
                        The location of the repo checkout.
    -o OUTPUT_LOCATION, --output_location=OUTPUT_LOCATION
                        The location where the output markdown files should be written to.
    -r, --remove_emails
                        Remove email addresses from generated md files. (def True)
    -R, --remove_headers
                        Remove unneeded headers from files (MAINTAINER and AUTHOR). (def True)
    -w, --remove_whitespace
                        Remove whitespace (   ) from md files. (def True)
    -s, --small_titles  Decrease the title size in the md files. (def True)

  Debug and logging options (configfile section MAIN):
    -d, --debug         Enable debug log mode (def False)
    --info              Enable info log mode (def False)
    --quiet             Enable quiet/warning log mode (def False)



It makes some assumpions on several repositories being in place.
To help set this up a helper script was added **build-quattor-documentation.sh** which builds the whole documentation from latest master.
