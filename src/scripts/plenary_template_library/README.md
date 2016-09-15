Script used to fetch and prepare the template libraries for use with aquilon.

This can be run every so often as a cron job or manually for a specific release (or RC) e.g. `plenary_template_library.py --release 16.8.0 /var/quattor/cfg/plenary/template-library/`

Each release is placed in a top level directory with the libraries underneath, this allows archetypes to switch releases using `LOADPATH` while preventing local modification of the libraries by users (as they are in the plenary rather than the git repository).

For example, 16.8.0 would appear as follows:
```
/var/quattor/cfg/plenary/template-library/16.8.0/
  ├── core/
  │   ├── components/
  │   ├── metaconfig/
  │   ├── pan/
  │   ├── quattor/
  ├── grid/
  │   ├── emi-2/
  │   ├── umd-3/
  ├── os/
  │   ├── el7.x-x86_64/
  │   ├── sl5.x-x86_64/
  │   ├── sl6.x-x86_64/
  ├── standard/
      ├── features/
      ├── filesystem/
      ├── glite/
      ├── hardware/
      ├── machine-types/
      ├── os/
      ├── personality/
      ├── repository/
      ├── security/
      ├── users/
      ├── xen/
```

Which can be used by setting (in `archetype/base`):
```pan
final variable QUATTOR_RELEASE = '16.8.0';

variable LOADPATH = prepend(SELF, format('template-library/%s/core', QUATTOR_RELEASE));
variable LOADPATH = prepend(SELF, format('template-library/%s/standard', QUATTOR_RELEASE))
```

The OS libraries can be used by setting (in the OS config e.g. `os/sl/7x-x86_64/config`):
```pan
variable LOADPATH = append(SELF, format('template-library/%s/os/el7.x-x86_64', QUATTOR_RELEASE));
```

The grid library (when needed) can be used by setting:
```pan
variable LOADPATH = prepend(SELF, format('template-library/%s/grid/%s', QUATTOR_RELEASE, GRID_MIDDLEWARE_RELEASE));
```
