@@ lua tests/oracle/fixtures/lua/control.lua
(chunk	0-221
  (for_statement	0-130
    clause: (for_numeric_clause	4-13
      name: (identifier	4-5)
      start: (number	8-9)
      end: (number	11-13))
    body: (block	19-126
      (if_statement	19-111
        condition: (binary_expression	22-32
          left: (binary_expression	22-27
            left: (identifier	22-23)
            right: (number	26-27))
          right: (number	31-32))
        consequence: (block	42-50
          (function_call	42-50
            name: (identifier	42-47)
            arguments: (arguments	47-50
              (identifier	48-49))))
        alternative: (elseif_statement	53-80
          condition: (binary_expression	60-65
            left: (identifier	60-61)
            right: (number	64-65))
          consequence: (block	75-80
            (break_statement	75-80)))
        alternative: (else_statement	83-105
          body: (block	92-105
            (goto_statement	92-105
              (identifier	97-105)))))
      (label_statement	114-126
        (identifier	116-124))))
  (while_statement	131-153
    condition: (identifier	137-138)
    body: (block	142-149
      (assignment_statement	142-149
        (variable_list	142-143
          name: (identifier	142-143))
        (expression_list	146-149
          value: (nil	146-149)))))
  (repeat_statement	154-180
    body: (block	161-172
      local_declaration: (variable_declaration	161-172
        (assignment_statement	167-172
          (variable_list	167-168
            name: (identifier	167-168))
          (expression_list	171-172
            value: (number	171-172)))))
    condition: (identifier	179-180))
  (for_statement	181-220
    clause: (for_generic_clause	185-201
      (variable_list	185-189
        name: (identifier	185-186)
        name: (identifier	188-189))
      (expression_list	193-201
        (function_call	193-201
          name: (identifier	193-198)
          arguments: (arguments	198-201
            (identifier	199-200)))))
    body: (block	205-216
      (function_call	205-216
        name: (identifier	205-210)
        arguments: (arguments	210-216
          (identifier	211-212)
          (identifier	214-215))))))
