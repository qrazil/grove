@@ c tests/oracle/fixtures/c/expr.c
(translation_unit	0-156
  (function_definition	0-155
    type: (primitive_type	0-3)
    declarator: (function_declarator	4-19
      declarator: (identifier	4-5)
      parameters: (parameter_list	5-19
        (parameter_declaration	6-11
          type: (primitive_type	6-9)
          declarator: (identifier	10-11))
        (parameter_declaration	13-18
          type: (primitive_type	13-16)
          declarator: (identifier	17-18))))
    body: (compound_statement	20-155
      (declaration	26-59
        type: (primitive_type	26-29)
        declarator: (init_declarator	30-58
          declarator: (identifier	30-31)
          value: (binary_expression	34-58
            left: (binary_expression	34-43
              left: (identifier	34-35)
              right: (binary_expression	38-43
                left: (identifier	38-39)
                right: (number_literal	42-43)))
            right: (binary_expression	46-58
              left: (parenthesized_expression	46-54
                (binary_expression	47-53
                  left: (identifier	47-48)
                  right: (number_literal	52-53)))
              right: (identifier	57-58)))))
      (expression_statement	64-91
        (assignment_expression	64-90
          left: (identifier	64-65)
          right: (binary_expression	69-90
            left: (binary_expression	69-84
              left: (binary_expression	69-74
                left: (identifier	69-70)
                right: (identifier	73-74))
              right: (binary_expression	78-84
                left: (identifier	78-79)
                right: (number_literal	83-84)))
            right: (unary_expression	88-90
              argument: (identifier	89-90)))))
      (expression_statement	96-110
        (conditional_expression	96-109
          condition: (assignment_expression	96-101
            left: (identifier	96-97)
            right: (identifier	100-101))
          consequence: (identifier	104-105)
          alternative: (identifier	108-109)))
      (return_statement	115-153
        (binary_expression	122-152
          left: (binary_expression	122-129
            left: (unary_expression	122-124
              argument: (identifier	123-124))
            right: (unary_expression	127-129
              argument: (identifier	128-129)))
          right: (sizeof_expression	132-152
            value: (cast_expression	138-152
              type: (type_descriptor	139-142
                type: (primitive_type	139-142))
              value: (unary_expression	144-152
                argument: (cast_expression	146-152
                  type: (type_descriptor	147-150
                    type: (primitive_type	147-150))
                  value: (identifier	151-152))))))))))
