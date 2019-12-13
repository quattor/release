Script used to fetch and prepare the template libraries for use with aquilon.

This can be run every so often as a cron job or manually for a specific release (or RC) e.g. `plenary_template_library.py --release 16.8.0 /var/quattor/cfg/plenary/template-library/`

Each release is placed in a top level directory with the libraries underneath, this allows archetypes to switch releases using `LOADPATH` while preventing local modification of the libraries by users (as they are in the plenary rather than the git repository).

For example, 18.3.0 would appear as follows:
```
/var/quattor/cfg/plenary/template-library/16.8.0/
  ├── core/
  │   ├── components/
  │   ├── metaconfig/
  │   ├── pan/
  │   ├── quattor/
  ├── grid/
  │   ├── umd-3/
  │   ├── umd-4/
  ├── openstack/
  │   ├── mitaka/
  │   ├── newton/
  │   ├── ocata/
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

Which can be used by setting (in `archetype/declarations`):
```pan
declaration template archetype/declarations;

# Replace by the template library version you want to use
final variable QUATTOR_RELEASE = '18.3.0';

variable LOADPATH = append(SELF, format('template-library/%s/core', QUATTOR_RELEASE));
variable LOADPATH = append(SELF, format('template-library/%s/standard', QUATTOR_RELEASE));

# The following to add OS templates is better placed in 'config/os/distribution/version'
# If you add it here, you need to define NODE_OS_VERSION to something like el7.x-x86_64
#variable LOADPATH = append(SELF, format('template-library/%s/os/%s', QUATTOR_RELEASE, NODE_OS_VERSION));

# To use UMD grid middleware templates, uncomment the following lines or place them in archetype/base
#final variable GRID_MIDDLEWARE_RELEASE = 'umd-4';
#variable LOADPATH = append(SELF, format('template-library/%s/grid/%s', QUATTOR_RELEASE, GRID_MIDDLEWARE_RELEASE));

# To use OpenStack templates, uncomment the following lines or place them in archetype/base
#final variable OPENSTACK_RELEASE = 'newton';
#variable LOADPATH = append(SELF, format('template-library/%s/openstack/%s', QUATTOR_RELEASE, OPENSTACK_RELEASE));

variable DEBUG = debug(format('%s: (template=%S) LOADPATH=%s', OBJECT, TEMPLATE, to_string(LOADPATH)));
```

To use this template, `object_declarations_template` must be set to true in the `panc` section of `aqd.conf`.
