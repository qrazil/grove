@@ c tests/oracle/fixtures/c/control.c
(translation_unit	0-304
  (function_definition	0-303
    type: (primitive_type	0-4)
    declarator: (function_declarator	5-15
      declarator: (identifier	5-8)
      parameters: (parameter_list	8-15
        (parameter_declaration	9-14
          type: (primitive_type	9-12)
          declarator: (identifier	13-14))))
    body: (compound_statement	16-303
      (for_statement	22-155
        initializer: (declaration	27-37
          type: (primitive_type	27-30)
          declarator: (init_declarator	31-36
            declarator: (identifier	31-32)
            value: (number_literal	35-36)))
        condition: (binary_expression	38-43
          left: (identifier	38-39)
          right: (identifier	42-43))
        update: (update_expression	45-48
          argument: (identifier	45-46))
        body: (compound_statement	50-155
          (if_statement	60-117
            condition: (parenthesized_expression	63-75
              (binary_expression	64-74
                left: (binary_expression	64-69
                  left: (identifier	64-65)
                  right: (number_literal	68-69))
                right: (number_literal	73-74)))
            consequence: (continue_statement	76-85)
            alternative: (if_statement	99-117
              condition: (parenthesized_expression	102-110
                (binary_expression	103-109
                  left: (identifier	103-104)
                  right: (number_literal	107-109)))
              consequence: (break_statement	111-117)))
          (while_statement	126-149
            condition: (parenthesized_expression	132-137
              (update_expression	133-136
                argument: (identifier	133-134)))
            body: (compound_statement	138-149
              (expression_statement	140-147
                (assignment_expression	140-146
                  left: (identifier	140-141)
                  right: (number_literal	145-146)))))))
      (switch_statement	160-252
        condition: (parenthesized_expression	167-170
          (identifier	168-169))
        body: (compound_statement	171-252
          (case_statement	177-214
            value: (number_literal	182-183)
            (expression_statement	193-199
              (assignment_expression	193-198
                left: (identifier	193-194)
                right: (number_literal	197-198)))
            (break_statement	208-214))
          (case_statement	219-246
            (goto_statement	236-246
              label: (statement_identifier	241-245)))))
      (do_statement	257-283
        body: (compound_statement	260-268
          (expression_statement	262-266
            (update_expression	262-265
              argument: (identifier	262-263))))
        condition: (parenthesized_expression	275-282
          (binary_expression	276-281
            left: (identifier	276-277)
            right: (number_literal	280-281))))
      (labeled_statement	284-301
        label: (statement_identifier	284-288)
        (return_statement	294-301)))))
