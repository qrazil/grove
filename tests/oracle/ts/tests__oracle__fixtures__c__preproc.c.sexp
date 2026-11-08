@@ c tests/oracle/fixtures/c/preproc.c
(translation_unit	0-267
  (preproc_ifdef	0-266
    name: (identifier	8-15)
    (preproc_def	16-32
      name: (identifier	24-31))
    (preproc_function_def	32-74
      name: (identifier	40-43)
      parameters: (preproc_params	43-49
        (identifier	44-45)
        (identifier	47-48))
      value: (preproc_arg	49-73))
    (preproc_def	74-92
      name: (identifier	82-89)
      value: (preproc_arg	89-91))
    (preproc_if	92-178
      condition: (binary_expression	96-127
        left: (preproc_defined	96-112
          (identifier	104-111))
        right: (binary_expression	116-127
          left: (identifier	116-123)
          right: (number_literal	126-127)))
      (declaration	128-146
        type: (primitive_type	128-131)
        declarator: (function_declarator	132-145
          declarator: (identifier	132-139)
          parameters: (parameter_list	139-145
            (parameter_declaration	140-144
              type: (primitive_type	140-144)))))
      alternative: (preproc_else	147-171
        (declaration	153-171
          type: (primitive_type	153-156)
          declarator: (function_declarator	157-170
            declarator: (identifier	157-164)
            parameters: (parameter_list	164-170
              (parameter_declaration	165-169
                type: (primitive_type	165-169)))))))
    (comment	179-201)
    (function_definition	202-247
      (storage_class_specifier	202-208)
      (storage_class_specifier	209-215)
      type: (primitive_type	216-219)
      declarator: (function_declarator	220-229
        declarator: (identifier	220-222)
        parameters: (parameter_list	222-229
          (parameter_declaration	223-228
            type: (primitive_type	223-226)
            declarator: (identifier	227-228))))
      body: (compound_statement	230-247
        (return_statement	232-245
          (binary_expression	239-244
            left: (identifier	239-240)
            right: (identifier	243-244)))))
    (comment	248-259)))
