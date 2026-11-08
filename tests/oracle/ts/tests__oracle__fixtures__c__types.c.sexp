@@ c tests/oracle/fixtures/c/types.c
(translation_unit	0-308
  (comment	0-25)
  (type_definition	26-56
    type: (sized_type_specifier	34-47)
    declarator: (type_identifier	48-55))
  (struct_specifier	57-83
    name: (type_identifier	64-69)
    body: (field_declaration_list	70-83
      (field_declaration	72-81
        type: (primitive_type	72-75)
        declarator: (field_identifier	76-77)
        declarator: (field_identifier	79-80))))
  (union_specifier	85-125
    name: (type_identifier	91-96)
    body: (field_declaration_list	97-125
      (field_declaration	99-105
        type: (primitive_type	99-102)
        declarator: (field_identifier	103-104))
      (field_declaration	106-114
        type: (primitive_type	106-111)
        declarator: (field_identifier	112-113))
      (field_declaration	115-123
        type: (primitive_type	115-119)
        declarator: (pointer_declarator	120-122
          declarator: (field_identifier	121-122)))))
  (enum_specifier	127-162
    name: (type_identifier	132-137)
    body: (enumerator_list	138-162
      (enumerator	140-143
        name: (identifier	140-143))
      (enumerator	145-154
        name: (identifier	145-150)
        value: (number_literal	153-154))
      (enumerator	156-160
        name: (identifier	156-160))))
  (declaration	164-211
    (storage_class_specifier	164-170)
    (type_qualifier	171-176)
    type: (primitive_type	177-181)
    declarator: (init_declarator	182-210
      declarator: (pointer_declarator	182-190
        declarator: (array_declarator	183-190
          declarator: (identifier	183-188)))
      value: (initializer_list	193-210
        (string_literal	195-198)
        (string_literal	200-203)
        (string_literal	205-208))))
  (declaration	212-231
    (storage_class_specifier	212-218)
    type: (primitive_type	219-222)
    declarator: (identifier	223-230))
  (declaration	232-265
    type: (primitive_type	232-235)
    declarator: (function_declarator	236-264
      declarator: (parenthesized_declarator	236-247
        (pointer_declarator	237-246
          declarator: (identifier	238-246)))
      parameters: (parameter_list	247-264
        (parameter_declaration	248-254
          type: (primitive_type	248-252)
          declarator: (abstract_pointer_declarator	253-254))
        (parameter_declaration	256-263
          type: (type_identifier	256-263)))))
  (declaration	266-307
    type: (struct_specifier	266-278
      name: (type_identifier	273-278))
    declarator: (init_declarator	279-306
      declarator: (identifier	279-285)
      value: (initializer_list	288-306
        (initializer_pair	290-296
          designator: (field_designator	290-292
            (field_identifier	291-292))
          value: (number_literal	295-296))
        (initializer_pair	298-304
          designator: (field_designator	298-300
            (field_identifier	299-300))
          value: (number_literal	303-304))))))
