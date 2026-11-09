@@ lua tests/oracle/fixtures/lua/functions.lua
(chunk	0-227
  local_declaration: (function_declaration	0-43
    name: (identifier	15-18)
    parameters: (parameters	18-24
      name: (identifier	19-20)
      name: (identifier	22-23))
    body: (block	27-39
      (return_statement	27-39
        (expression_list	34-39
          (binary_expression	34-39
            left: (identifier	34-35)
            right: (identifier	38-39))))))
  (function_declaration	44-81
    name: (dot_index_expression	53-58
      table: (identifier	53-54)
      field: (identifier	55-58))
    parameters: (parameters	58-64
      name: (identifier	59-60)
      name: (identifier	62-63))
    body: (block	65-77
      (return_statement	65-77
        (expression_list	72-77
          (binary_expression	72-77
            left: (identifier	72-73)
            right: (identifier	76-77))))))
  (function_declaration	82-162
    name: (method_index_expression	91-99
      table: (identifier	91-92)
      method: (identifier	93-99))
    parameters: (parameters	99-104
      (vararg_expression	100-103))
    body: (block	107-158
      local_declaration: (variable_declaration	107-125
        (assignment_statement	113-125
          (variable_list	113-117
            name: (identifier	113-117))
          (expression_list	120-125
            value: (table_constructor	120-125
              (field	121-124
                value: (vararg_expression	121-124))))))
      (return_statement	128-158
        (expression_list	135-158
          (unary_expression	135-140
            operand: (identifier	136-140))
          (function_call	142-158
            name: (identifier	142-148)
            arguments: (arguments	148-158
              (string	149-152
                content: (string_content	150-151))
              (vararg_expression	154-157)))))))
  local_declaration: (variable_declaration	163-201
    (assignment_statement	169-201
      (variable_list	169-170
        name: (identifier	169-170))
      (expression_list	173-201
        value: (function_definition	173-201
          parameters: (parameters	181-184
            name: (identifier	182-183))
          body: (block	185-197
            (return_statement	185-197
              (expression_list	192-197
                (binary_expression	192-197
                  left: (identifier	192-193)
                  right: (number	196-197)))))))))
  (function_call	202-226
    name: (identifier	202-207)
    arguments: (arguments	207-226
      (function_call	208-217
        name: (identifier	208-211)
        arguments: (arguments	211-217
          (number	212-213)
          (number	215-216)))
      (parenthesized_expression	219-225
        (function_call	220-224
          name: (identifier	220-221)
          arguments: (arguments	221-224
            (number	222-223)))))))
