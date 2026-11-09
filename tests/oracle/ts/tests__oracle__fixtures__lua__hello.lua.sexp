@@ lua tests/oracle/fixtures/lua/hello.lua
(chunk	0-53
  local_declaration: (variable_declaration	0-20
    (assignment_statement	6-20
      (variable_list	6-10
        name: (identifier	6-10))
      (expression_list	13-20
        value: (string	13-20
          content: (string_content	14-19)))))
  (function_call	21-52
    name: (identifier	21-26)
    arguments: (arguments	26-52
      (binary_expression	27-51
        left: (string	27-36
          content: (string_content	28-35))
        right: (binary_expression	40-51
          left: (identifier	40-44)
          right: (string	48-51
            content: (string_content	49-50)))))))
