@@ c tests/oracle/fixtures/c/hello.c
(translation_unit	0-127
  (preproc_include	0-20
    path: (system_lib_string	9-18))
  (function_definition	20-126
    type: (primitive_type	20-23)
    declarator: (function_declarator	24-51
      declarator: (identifier	24-28)
      parameters: (parameter_list	28-51
        (parameter_declaration	29-37
          type: (primitive_type	29-32)
          declarator: (identifier	33-37))
        (parameter_declaration	39-50
          type: (primitive_type	39-43)
          declarator: (pointer_declarator	44-50
            declarator: (pointer_declarator	45-50
              declarator: (identifier	46-50))))))
    body: (compound_statement	52-126
      (expression_statement	58-110
        (call_expression	58-109
          function: (identifier	58-64)
          arguments: (argument_list	64-109
            (string_literal	65-78
              (escape_sequence	75-77))
            (conditional_expression	80-108
              condition: (binary_expression	80-88
                left: (identifier	80-84)
                right: (number_literal	87-88))
              consequence: (subscript_expression	91-98
                argument: (identifier	91-95)
                index: (number_literal	96-97))
              alternative: (string_literal	101-108)))))
      (return_statement	115-124
        (number_literal	122-123)))))
