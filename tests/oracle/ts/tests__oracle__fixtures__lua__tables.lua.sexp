@@ lua tests/oracle/fixtures/lua/tables.lua
(chunk	0-184
  local_declaration: (variable_declaration	0-67
    (assignment_statement	6-67
      (variable_list	6-7
        name: (identifier	6-7))
      (expression_list	10-67
        value: (table_constructor	10-67
          (field	12-13
            value: (number	12-13))
          (field	15-16
            value: (number	15-16))
          (field	18-19
            value: (number	18-19))
          (field	21-26
            name: (identifier	21-22)
            value: (number	25-26))
          (field	28-39
            name: (string	29-34
              content: (string_content	30-33))
            value: (number	38-39))
          (field	41-64
            name: (number	42-43)
            value: (table_constructor	47-64
              (field	49-62
                name: (identifier	49-55)
                value: (true	58-62))))))))
  (assignment_statement	68-84
    (variable_list	68-75
      name: (dot_index_expression	68-75
        table: (dot_index_expression	68-73
          table: (dot_index_expression	68-71
            table: (identifier	68-69)
            field: (identifier	70-71))
          field: (identifier	72-73))
        field: (identifier	74-75)))
    (expression_list	78-84
      value: (bracket_index_expression	78-84
        table: (identifier	78-79)
        field: (string	80-83
          content: (string_content	81-82)))))
  local_declaration: (variable_declaration	85-120
    (assignment_statement	91-120
      (variable_list	91-92
        name: (identifier	91-92))
      (expression_list	95-120
        value: (binary_expression	95-120
          left: (binary_expression	95-113
            left: (unary_expression	95-97
              operand: (identifier	96-97))
            right: (binary_expression	100-113
              left: (binary_expression	100-108
                left: (bracket_index_expression	100-104
                  table: (identifier	100-101)
                  field: (number	102-103))
                right: (number	107-108))
              right: (number	112-113)))
          right: (string	117-120
            content: (string_content	118-119))))))
  (return_statement	121-183
    (expression_list	128-183
      (table_constructor	128-183
        (field	130-135
          name: (identifier	130-131)
          value: (identifier	134-135))
        (field	137-142
          name: (identifier	137-138)
          value: (identifier	141-142))
        (field	144-157
          name: (identifier	144-151)
          value: (nil	154-157))
        (field	159-169
          name: (identifier	159-162)
          value: (true	165-169))
        (field	171-181
          name: (identifier	171-173)
          value: (false	176-181))))))
