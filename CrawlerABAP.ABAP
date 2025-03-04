*&---------------------------------------------------------------------*
*& Report ZCAR_CRAWLER
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zcar_crawler.

PARAMETERS: p_prog TYPE progname.
PARAMETERS: p_clas TYPE progname.
PARAMETERS: p_func TYPE progname.

TYPE-POOLS: seoc,
            seop.

TYPES: BEGIN OF ty_dependency,
         object       TYPE string,
         obj_type     TYPE string,
         source       TYPE w3_htmltab,
         dependencies TYPE REF TO data,
       END OF ty_dependency,
       tt_dependency TYPE TABLE OF ty_dependency WITH DEFAULT KEY.
FIELD-SYMBOLS: <fs_dependencies> TYPE tt_dependency.
FIELD-SYMBOLS: <fs_list_dependency> TYPE tt_dependency.


CLASS lcl_crawler DEFINITION.

  PUBLIC SECTION.

    DATA: gt_objects TYPE TABLE OF ty_dependency.

    DATA: gv_is_include TYPE xfeld.


    METHODS: constructor          IMPORTING iv_prog TYPE progname
                                            iv_clas TYPE progname
                                            iv_func TYPE progname.
    METHODS: start_crawler_prog   CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_class  CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_funct  CHANGING  cs_object TYPE ty_dependency.

    METHODS: add_program  IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.
    METHODS: add_class    IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.
    METHODS: add_function IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.

    METHODS: display_dependencies.

ENDCLASS.

CLASS lcl_crawler IMPLEMENTATION.

  METHOD constructor.

    " >>> Inicia o Objeto
    DATA ls_objects LIKE LINE OF gt_objects.
    " <<< Inicia o Objeto

    " Se for um Programa
    IF iv_prog IS NOT INITIAL.
      ls_objects-object = iv_prog.
      ls_objects-obj_type = 'PROGRAM'.
      start_crawler_prog( CHANGING cs_object = ls_objects ).
    ENDIF.

    IF iv_clas IS NOT INITIAL.
      ls_objects-object = iv_clas.
      ls_objects-obj_type = 'CLASS'.
      start_crawler_class( CHANGING cs_object = ls_objects ).
    ENDIF.

    IF iv_func IS NOT INITIAL.
      ls_objects-object = iv_clas.
      ls_objects-obj_type = 'FUNCTION'.
      start_crawler_funct( CHANGING cs_object = ls_objects ).
    ENDIF.

    APPEND ls_objects TO gt_objects.

    display_dependencies( ).

  ENDMETHOD.

  METHOD start_crawler_prog.

    ">>> Inicia o Objeto
    DATA lv_object_name TYPE progname.
    lv_object_name = CONV progname( cs_object-object ).
    READ REPORT lv_object_name INTO cs_object-source.

    DELETE cs_object-source WHERE table_line(1) = '*' OR table_line(1) = |"|.

    CREATE DATA cs_object-dependencies TYPE TABLE OF ty_dependency.
    "<<< Inicia o Objeto

    LOOP AT cs_object-source INTO DATA(ls_source).

      CHECK ls_source IS NOT INITIAL.

      " Se Tiver Classes Adiciona
      add_program( EXPORTING is_source = ls_source
                   CHANGING  cs_object = cs_object ).

      " Se Tiver Programas Adiciona
      add_class( EXPORTING is_source = ls_source
                 CHANGING  cs_object = cs_object ).

      " Se Tiver Funções Adiciona
      add_function( EXPORTING is_source = ls_source
                    CHANGING  cs_object = cs_object ).

    ENDLOOP.

  ENDMETHOD.

  METHOD start_crawler_class.

    DATA: lo_cifref       TYPE REF TO if_oo_clif_incl_naming.
    DATA: lo_clsref       TYPE REF TO if_oo_class_incl_naming.
    DATA: lt_source_pool  TYPE seop_source_string.
    DATA: lt_source       TYPE seop_source_string.
    DATA: lv_tabix        TYPE sy-tabix.

    ">>> Inicia o Objeto
    CREATE DATA cs_object-dependencies TYPE TABLE OF ty_dependency.
    "<<< Inicia o Objeto

    " Montar o Source da Classe
    CALL METHOD cl_oo_include_naming=>get_instance_by_cifkey
      EXPORTING
        cifkey = CONV seoclskey( cs_object-object )
      RECEIVING
        cifref = lo_cifref
      EXCEPTIONS
        OTHERS = 1.

    lo_clsref ?= lo_cifref.

    IF lo_clsref IS NOT BOUND.
      RETURN.
    ENDIF.

    READ REPORT lo_clsref->class_pool
      INTO lt_source_pool.
    LOOP AT lt_source_pool INTO DATA(source_line).
      IF   source_line CP 'CLASS-POOL'
        OR source_line CP 'class-pool'.
        lv_tabix = sy-tabix.
        APPEND source_line TO cs_object-source.
        EXIT.
      ENDIF.
    ENDLOOP.

    READ REPORT lo_clsref->locals_old
      INTO lt_source.
    LOOP AT lt_source
      INTO source_line.
      IF source_line NS '*"*'.
        APPEND source_line TO cs_object-source.
      ENDIF.
    ENDLOOP.

    READ REPORT lo_clsref->locals_def
      INTO lt_source.
    LOOP AT lt_source
      INTO source_line.
      IF source_line NS '*"*'.
        APPEND source_line TO cs_object-source.
      ENDIF.
    ENDLOOP.

    READ REPORT lo_clsref->locals_imp
      INTO lt_source.
    LOOP AT lt_source
      INTO source_line.
      IF source_line NS '*"*'.
        APPEND source_line TO cs_object-source.
      ENDIF.
    ENDLOOP.

    READ REPORT lo_clsref->macros
      INTO lt_source.
    LOOP AT lt_source
      INTO source_line.
      IF source_line NS '*"*'.
        APPEND source_line TO cs_object-source.
      ENDIF.
    ENDLOOP.

    READ REPORT lo_clsref->public_section
      INTO lt_source.
    LOOP AT lt_source
      INTO source_line.
      IF source_line NS '*"*'.
        APPEND source_line TO cs_object-source.
      ENDIF.
    ENDLOOP.

    READ REPORT lo_clsref->protected_section
      INTO lt_source.
    LOOP AT lt_source
      INTO source_line.
      IF source_line NS '*"*'.
        APPEND source_line TO cs_object-source.
      ENDIF.
    ENDLOOP.

    READ REPORT lo_clsref->private_section
      INTO lt_source.
    LOOP AT lt_source
      INTO source_line.
      IF source_line NS '*"*'.
        APPEND source_line TO cs_object-source.
      ENDIF.
    ENDLOOP.

    CONCATENATE 'CLASS' cs_object-object 'IMPLEMENTATION' INTO DATA(lv_string) SEPARATED BY space.
    LOOP AT lt_source_pool
      FROM lv_tabix
      INTO source_line.
      IF source_line CS 'ENDCLASS'.
        APPEND source_line TO cs_object-source.
      ENDIF.
      IF source_line CS lv_string.
        SKIP.
        APPEND source_line TO cs_object-source.
        lv_tabix = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.

    DATA(lt_includes) = lo_clsref->get_all_method_includes( ).
    LOOP AT lt_includes
      INTO DATA(ls_include).
      READ REPORT ls_include-incname INTO lt_source.
      SKIP.
      LOOP AT lt_source
        INTO source_line.
        APPEND source_line TO cs_object-source.
      ENDLOOP.
    ENDLOOP.
    LOOP AT lt_source_pool
      FROM lv_tabix
      INTO source_line.
      IF source_line CS 'ENDCLASS'.
        APPEND source_line TO cs_object-source.
      ENDIF.
    ENDLOOP.

    DELETE cs_object-source WHERE table_line(1) = '*' OR table_line(1) = |"|.

    LOOP AT cs_object-source INTO DATA(ls_source).

      CHECK ls_source IS NOT INITIAL.

      " Se Tiver Programas Adiciona
      add_program( EXPORTING is_source = ls_source
                   CHANGING  cs_object = cs_object ).

      " Se Tiver Classes Adiciona
      add_class( EXPORTING is_source = ls_source
                 CHANGING  cs_object = cs_object ).

      " Se Tiver Funções Adiciona
      add_function( EXPORTING is_source = ls_source
                    CHANGING  cs_object = cs_object ).

    ENDLOOP.

  ENDMETHOD.

  METHOD start_crawler_funct.

    CREATE DATA cs_object-dependencies TYPE TABLE OF ty_dependency.

    DATA: lt_source TYPE TABLE OF rssource.
    DATA: lt_import_parameter TYPE TABLE OF rsimp.
    DATA: lt_changing_parameter TYPE TABLE OF rscha.
    DATA: lt_export_parameter TYPE TABLE OF rsexp.
    DATA: lt_tables_parameter TYPE TABLE OF rstbl.
    DATA: lt_exception_list TYPE TABLE OF rsexc.
    DATA: lt_documentation TYPE TABLE OF rsfdo.

    CALL FUNCTION 'RPY_FUNCTIONMODULE_READ'
      EXPORTING
        functionname       = CONV rs38l-name( cs_object-object )
      TABLES
        source             = lt_source
        import_parameter   = lt_import_parameter
        changing_parameter = lt_changing_parameter
        export_parameter   = lt_export_parameter
        tables_parameter   = lt_tables_parameter
        exception_list     = lt_exception_list
        documentation      = lt_documentation
      EXCEPTIONS
        error_message      = 1
        function_not_found = 2
        invalid_name       = 3
        OTHERS             = 4.

    cs_object-source = lt_source.

    LOOP AT cs_object-source INTO DATA(ls_source).

      CHECK ls_source IS NOT INITIAL.

      " Se Tiver Programas Adiciona
      add_program( EXPORTING is_source = ls_source
                   CHANGING  cs_object = cs_object ).

      " Se Tiver Classes Adiciona
      add_class( EXPORTING is_source = ls_source
                 CHANGING  cs_object = cs_object ).

      " Se Tiver Funções Adiciona
      add_function( EXPORTING is_source = ls_source
                    CHANGING  cs_object = cs_object ).

    ENDLOOP.

    CLEAR: lt_source[].

  ENDMETHOD.

  METHOD display_dependencies.

    DATA(lv_json) = /ui2/cl_json=>serialize( gt_objects ).

    CALL TRANSFORMATION sjson2html SOURCE XML lv_json
                               RESULT XML DATA(html).

    cl_abap_browser=>show_html( html_string = cl_abap_codepage=>convert_from( html ) ).

  ENDMETHOD.


  METHOD add_function.

    IF is_source CS 'CALL FUNCTION'.

      DATA ls_dependency TYPE ty_dependency.

      SPLIT is_source AT ' ' INTO TABLE DATA(lt_rf_fn).
      DATA(lv_last_line_fn) = lines( lt_rf_fn ).

      DATA(lv_func_name) = lt_rf_fn[ lv_last_line_fn ].

      REPLACE ALL OCCURRENCES OF '.' IN lv_func_name WITH ''.
      REPLACE ALL OCCURRENCES OF ',' IN lv_func_name WITH ''.
      REPLACE ALL OCCURRENCES OF '(' IN lv_func_name WITH ''.
      REPLACE ALL OCCURRENCES OF |'| IN lv_func_name WITH ''.
      TRANSLATE lv_func_name TO UPPER CASE.

      IF lv_func_name(1) <> 'Z'.
        RETURN.
      ENDIF.

      " >>> Inicia o Objeto
      ls_dependency-object   = lv_func_name.
      ls_dependency-obj_type = 'FUNCTION'.

      start_crawler_funct( CHANGING cs_object = ls_dependency ).

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.

      APPEND ls_dependency TO <fs_dependencies>.

    ENDIF.

  ENDMETHOD.

  METHOD add_program.

    " Programas Include
    IF is_source CS 'INCLUDE' OR gv_is_include = 'X'.

      DATA ls_dependency TYPE ty_dependency.

      gv_is_include = 'X'.
      IF is_source CS '.'.
        gv_is_include = ''.
      ENDIF.

      SPLIT is_source AT ' ' INTO TABLE DATA(lt_object).
      DATA(lv_last_line_include) = lines( lt_object ).

      DATA(lv_name_object) = lt_object[ lv_last_line_include ].
      REPLACE ALL OCCURRENCES OF '.' IN lv_name_object WITH ''.
      REPLACE ALL OCCURRENCES OF ',' IN lv_name_object WITH ''.
      TRANSLATE lv_name_object TO UPPER CASE.

      SELECT SINGLE object
        FROM tadir
        WHERE obj_name = @lv_name_object
          AND object   = 'PROG'
        INTO @DATA(lv_tadir).

      IF ( lv_name_object(1) <> 'Y' AND lv_name_object(1) <> 'Z' ) OR lv_tadir IS INITIAL.
        RETURN.
      ENDIF.
      CLEAR: lv_tadir.

      " >>> Inicia o Objeto
      ls_dependency-object   = lv_name_object.
      ls_dependency-obj_type = 'INCLUDE'.

      start_crawler_prog( CHANGING cs_object = ls_dependency ).

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.

      APPEND ls_dependency TO <fs_dependencies>.
    ENDIF.

  ENDMETHOD.

  METHOD add_class.

    " Classes REF TO ou NEW
    IF is_source CS 'TYPE REF TO' OR is_source CS 'NEW'.

      DATA ls_dependency TYPE ty_dependency.

      SPLIT is_source AT ' ' INTO TABLE DATA(lt_rf_to).
      DATA(lv_last_line) = lines( lt_rf_to ).

      DATA(lv_class_name) = lt_rf_to[ lv_last_line ].
      IF lv_class_name = ').' OR lv_class_name = '.'.
        lv_class_name = lt_rf_to[ lv_last_line - 1 ].
      ENDIF.

      REPLACE ALL OCCURRENCES OF '.' IN lv_class_name WITH ''.
      REPLACE ALL OCCURRENCES OF ',' IN lv_class_name WITH ''.
      REPLACE ALL OCCURRENCES OF '(' IN lv_class_name WITH ''.
      TRANSLATE lv_class_name TO UPPER CASE.

      SELECT SINGLE object
        FROM tadir
        WHERE obj_name = @lv_class_name
          AND object   = 'CLAS'
        INTO @DATA(lv_tadir).

      IF ( lv_class_name(1) <> 'Y' AND lv_class_name(1) <> 'Z' ) OR lv_tadir IS INITIAL.
        RETURN.
      ENDIF.
      CLEAR: lv_tadir.

      " >>> Inicia o Objeto
      ls_dependency-object   = lv_class_name.
      ls_dependency-obj_type = 'CLASS'.

      start_crawler_class( CHANGING cs_object = ls_dependency ).

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.

      APPEND ls_dependency TO <fs_dependencies>.

    ENDIF.

  ENDMETHOD.

ENDCLASS.


INITIALIZATION.
  %_p_prog_%_app_%-text = 'Programa: '.
  %_p_clas_%_app_%-text = 'Classe: '.
  %_p_func_%_app_%-text = 'Função: '.

START-OF-SELECTION.
  NEW lcl_crawler( iv_prog = p_prog
                   iv_clas = p_clas
                   iv_func = p_func ).
