@@ c tests/oracle/fixtures/c/micro/resolve.c
(translation_unit	0-138
  (function_definition	0-137
    type: (primitive_type	0-4)
    declarator: (function_declarator	5-12
      declarator: (identifier	5-6)
      parameters: (parameter_list	6-12
        (parameter_declaration	7-11
          type: (primitive_type	7-11))))
    body: (compound_statement	13-137
      (if_statement	19-63
        condition: (parenthesized_expression	22-25
          (identifier	23-24))
        consequence: (if_statement	34-63
          condition: (parenthesized_expression	37-40
            (identifier	38-39))
          consequence: (expression_statement	41-45
            (call_expression	41-44
              function: (identifier	41-42)
              arguments: (argument_list	42-44)))
          alternative: (expression_statement	59-63
            (call_expression	59-62
              function: (identifier	59-60)
              arguments: (argument_list	60-62)))))
      (expression_statement	68-99
        (call_expression	68-98
          function: (identifier	68-74)
          arguments: (argument_list	74-98
            (pointer_expression	75-80
              argument: (identifier	76-80))
            (number_literal	82-83)
            (sizeof_expression	85-97
              value: (parenthesized_expression	91-97
                (identifier	92-96))))))
      (expression_statement	104-114
        (assignment_expression	104-113
          left: (identifier	104-105)
          right: (assignment_expression	108-113
            left: (identifier	108-109)
            right: (identifier	112-113))))
      (expression_statement	119-135
        (assignment_expression	119-134
          left: (identifier	119-120)
          right: (sizeof_expression	123-134
            type: (type_descriptor	130-133
              type: (primitive_type	130-133))))))))
