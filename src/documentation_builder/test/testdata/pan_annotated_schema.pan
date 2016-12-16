declaration template pan_annotated_schema;

@documentation {test type.}
type testtype = {
    @{Test long.}
    'debug' : long(0..1) = 0
    @{Test string}
    'ca_dir' ? string
};

@documentation{
  desc = simple addition of two numbers
  arg = first number to add
  arg = second number to add
}
function add = {
 ARGV[0] + ARGV[1];
};
