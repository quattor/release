# Opennebula OneFlow build_all_repos

## Images
Get the [CentOS 5][centos5], [CentOS 6][centos6] and [CentOS 7][centos7] images for the marketplace

[centos5]: http://marketplace.opennebula.systems/appliance/5565cfba8fb81d6ebb000001
[centos6]: http://marketplace.opennebula.systems/appliance/53e767ba8fb81d6a69000001
[centos7]: http://marketplace.opennebula.systems/appliance/53e7bf928fb81d6a69000002

## Add the scripts
Add the scripts to the files datastore (`Files & Kernels`), both type `CONTEXT` 

 * [initscript][context_init_build_all_repos]
 * [build_all_repos][build_all_repos]
 
[context_init_build_all_repos]: https://raw.githubusercontent.com/quattor/release/master/src/scripts/context_init_build_all_repos.sh
[build_all_repos]: https://raw.githubusercontent.com/quattor/release/master/src/scripts/build_all_repos.sh

## VM templates

Make for each image a VM template with

* appriopriate name
 * INIT_SCRIPTS the `initscript`
 * regular SCRIPT `build_all_repos`

## OneFlow template
Click new, add one role for each VM template

## Instantiate
Instantiate the OneFlow template
