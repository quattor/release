############
test::schema
############

Types
-----

 - **component-testtesttype**
    - Description: test type.
    - *component-test/testtype/debug*
        - Description: Test long.
        - Required
        - Type: long
        - Range: 0..1
        - Default value: 0
    - *component-test/testtype/ca_dir*
        - Description: Test string
        - Optional
        - Type: string
    - *component-test/testtype/def*
        - Description: Test default
        - Required
        - Type: string
        - Default value: testdefault

Functions
---------

 - add
    - Description: simple addition of two numbers
    - Arguments:
        - first number to add
        - second number to add
