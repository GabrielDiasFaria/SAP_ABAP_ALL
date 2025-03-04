*&---------------------------------------------------------------------*
*& Report ZCAR_CRAWLER
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zcar_crawler.

PARAMETERS: p_prog TYPE progname.

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

    DATA:  gt_objects TYPE TABLE OF ty_dependency.


    METHODS: constructor          IMPORTING iv_prog   TYPE progname.
    METHODS: start_crawler_prog   CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_class  CHANGING  cs_object TYPE ty_dependency.
    METHODS: display_dependencies.

ENDCLASS.

CLASS lcl_crawler IMPLEMENTATION.

  METHOD constructor.

    " >>> Inicia o Objeto
    DATA ls_objects LIKE LINE OF gt_objects.
    ls_objects-object = iv_prog.
    " <<< Inicia o Objeto

    " Se for um Programa
    IF iv_prog IS NOT INITIAL.
      ls_objects-obj_type = 'PROGRAM'.
      start_crawler_prog( CHANGING cs_object = ls_objects ).
    ENDIF.

    APPEND ls_objects TO gt_objects.

    display_dependencies( ).

  ENDMETHOD.

  METHOD start_crawler_prog.

    DATA: lv_is_include TYPE xfeld.

    ">>> Inicia o Objeto
    DATA lv_object_name TYPE progname.
    lv_object_name = CONV progname( cs_object-object ).
    READ REPORT lv_object_name INTO cs_object-source.

    DELETE cs_object-source WHERE table_line(1) = '*' OR table_line(1) = |"|.

    CREATE DATA cs_object-dependencies TYPE TABLE OF ty_dependency.
    "<<< Inicia o Objeto

    LOOP AT cs_object-source INTO DATA(ls_source).

      DATA ls_dependency TYPE ty_dependency.

      " Programas Include
      IF ls_source CS 'INCLUDE' OR lv_is_include = 'X'.
        lv_is_include = 'X'.
        IF ls_source CS '.'.
          lv_is_include = ''.
        ENDIF.

        SPLIT ls_source AT ' ' INTO TABLE DATA(lt_object).
        DATA(lv_last_line_include) = lines( lt_object ).

        DATA(lv_name_object) = lt_object[ lv_last_line_include ].
        REPLACE ALL OCCURRENCES OF '.' IN lv_name_object WITH ''.
        REPLACE ALL OCCURRENCES OF ',' IN lv_name_object WITH ''.
        TRANSLATE lv_name_object TO UPPER CASE.

        " >>> Inicia o Objeto
        ls_dependency-object   = lv_name_object.
        ls_dependency-obj_type = 'PROGRAM'.

        start_crawler_prog( CHANGING cs_object = ls_dependency ).

        ASSIGN cs_object-dependencies->* TO <fs_dependencies>.

        APPEND ls_dependency TO <fs_dependencies>.
      ENDIF.

      " Classes REF TO ou NEW
      IF ls_source CS 'TYPE REF TO' OR ls_source CS 'NEW'.
        SPLIT ls_source AT ' ' INTO TABLE DATA(lt_rf_to).
        DATA(lv_last_line) = lines( lt_rf_to ).

        DATA(lv_class_name) = lt_rf_to[ lv_last_line ].
        IF lv_class_name = ').'.
          lv_class_name = lt_rf_to[ lv_last_line - 1 ].
        ENDIF.

        REPLACE ALL OCCURRENCES OF '.' IN lv_class_name WITH ''.
        REPLACE ALL OCCURRENCES OF ',' IN lv_class_name WITH ''.
        REPLACE ALL OCCURRENCES OF '(' IN lv_class_name WITH ''.
        TRANSLATE lv_class_name TO UPPER CASE.

        IF lv_class_name(1) <> 'Z'.
          CONTINUE.
        ENDIF.

        " >>> Inicia o Objeto
        ls_dependency-object   = lv_class_name.
        ls_dependency-obj_type = 'CLASS'.

        start_crawler_class( CHANGING cs_object = ls_dependency ).

        ASSIGN cs_object-dependencies->* TO <fs_dependencies>.

        APPEND ls_dependency TO <fs_dependencies>.

      ENDIF.

      CLEAR: ls_dependency.

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

    READ REPORT lo_clsref->class_pool
      INTO lt_source_pool.
    LOOP AT lt_source_pool INTO DATA(source_line).
      IF   source_line CS 'CLASS-POOL'
        OR source_line CS 'class-pool'.
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

*    LOOP AT cs_object-source INTO DATA(ls_source).
*
*      " Programas Include
*      IF ls_source CS 'INCLUDE'.
*        SPLIT ls_source AT ' ' INTO TABLE DATA(lt_object).
*
*        IF lines( lt_object ) = 2.
*          DATA(lv_name_object) = lt_object[ 2 ].
*          REPLACE ALL OCCURRENCES OF '.' IN lv_name_object WITH ''.
*          TRANSLATE lv_name_object TO UPPER CASE.
*
*          DATA ls_dependency TYPE ty_dependency.
*
*          " >>> Inicia o Objeto
*          ls_dependency-object   = lv_name_object.
*          ls_dependency-obj_type = 'PROG'.
*
*          start_crawler_prog( CHANGING cs_object = ls_dependency ).
*
*          ASSIGN cs_object-dependencies->* TO <fs_dependencies>.
*
*          APPEND ls_dependency TO <fs_dependencies>.
*
*        ENDIF.
*      ENDIF.
*
*    ENDLOOP.

  ENDMETHOD.

  METHOD display_dependencies.

    DATA(lv_json) = /ui2/cl_json=>serialize( gt_objects ).

    CALL TRANSFORMATION sjson2html SOURCE XML lv_json
                               RESULT XML DATA(html).

    cl_abap_browser=>show_html( html_string = cl_abap_codepage=>convert_from( html ) ).

  ENDMETHOD.

ENDCLASS.


INITIALIZATION.
  %_p_prog_%_app_%-text = 'Programa: '.

START-OF-SELECTION.
  NEW lcl_crawler( p_prog ).
