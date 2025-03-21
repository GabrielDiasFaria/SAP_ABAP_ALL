*&---------------------------------------------------------------------*
*& Report ZCAR_CRAWLER
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zcar_crawler.

PARAMETERS: p_prog TYPE progname.
PARAMETERS: p_clas TYPE progname.
PARAMETERS: p_func TYPE progname.
PARAMETERS: p_cds  TYPE progname.

PARAMETERS: ch_exp AS CHECKBOX.


TYPE-POOLS: seoc,
            seop.

TYPES: BEGIN OF ty_dependency,
         object           TYPE string,
         obj_type         TYPE string,
         obj_method       TYPE string,
         source           TYPE w3_htmltab,
         source_extension TYPE w3_htmltab,
         dependencies     TYPE REF TO data,
       END OF ty_dependency,
       tt_dependency TYPE TABLE OF ty_dependency WITH DEFAULT KEY.
FIELD-SYMBOLS: <fs_dependencies> TYPE tt_dependency.
FIELD-SYMBOLS: <fs_list_dependency> TYPE tt_dependency.

TYPES: BEGIN OF ty_classes,
         object   TYPE string,
         variable TYPE string,
         class    TYPE string,
       END OF ty_classes,
       tt_classes TYPE TABLE OF ty_classes WITH DEFAULT KEY.


CLASS lcl_crawler DEFINITION.

  PUBLIC SECTION.

    DATA: gt_objects TYPE TABLE OF ty_dependency.

    DATA: gv_is_include TYPE xfeld.

    DATA: gt_objects_list TYPE TABLE OF string.

    DATA: gt_classes TYPE tt_classes.

    METHODS: constructor          IMPORTING iv_prog TYPE progname
                                            iv_clas TYPE progname
                                            iv_func TYPE progname
                                            iv_cds  TYPE progname.
    METHODS: start_crawler_prog        CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_cds         CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_class       CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_full_class  CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_funct       CHANGING  cs_object TYPE ty_dependency.

    METHODS: add_program  IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.
    METHODS: add_class    IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.
    METHODS: add_function IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.
    METHODS: add_cds      IMPORTING is_source TYPE w3_html
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
      ls_objects-object   = iv_prog.
      ls_objects-obj_type = 'PROGRAM'.
      start_crawler_prog( CHANGING cs_object = ls_objects ).
    ENDIF.

    IF iv_clas IS NOT INITIAL AND ls_objects-source IS INITIAL.
      ls_objects-object   = iv_clas.
      ls_objects-obj_type = 'CLASS'.
      start_crawler_full_class( CHANGING cs_object = ls_objects ).
    ENDIF.

    IF iv_func IS NOT INITIAL AND ls_objects-source IS INITIAL.
      ls_objects-object   = iv_clas.
      ls_objects-obj_type = 'FUNCTION'.
      start_crawler_funct( CHANGING cs_object = ls_objects ).
    ENDIF.

    IF iv_cds IS NOT INITIAL AND ls_objects-source IS INITIAL.
      ls_objects-object   = iv_cds.
      ls_objects-obj_type = 'CDS'.
      start_crawler_cds( CHANGING cs_object = ls_objects ).
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
      CONDENSE ls_source.
      CHECK ls_source(1) NE '*' AND ls_source(1) NE '"'.

      " Se Tiver Classes Adiciona
      add_program( EXPORTING is_source = ls_source
                   CHANGING  cs_object = cs_object ).

      " Se Tiver Programas Adiciona
      add_class( EXPORTING is_source = ls_source
                 CHANGING  cs_object = cs_object ).

      " Se Tiver Funções Adiciona
      add_function( EXPORTING is_source = ls_source
                    CHANGING  cs_object = cs_object ).

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.
      SORT <fs_dependencies>.
      DELETE ADJACENT DUPLICATES FROM <fs_dependencies>.

    ENDLOOP.

  ENDMETHOD.

  METHOD start_crawler_class.

    ">>> Inicia o Objeto
    CREATE DATA cs_object-dependencies TYPE TABLE OF ty_dependency.
    "<<< Inicia o Objeto

    DATA lt_source TYPE seop_source.

    CALL FUNCTION 'SEO_METHOD_GET_SOURCE'
      EXPORTING
        mtdkey                        = VALUE seocpdkey( clsname = cs_object-object cpdname = cs_object-obj_method )
      IMPORTING
        source                        = lt_source
      EXCEPTIONS
        _internal_method_not_existing = 1
        _internal_class_not_existing  = 2
        version_not_existing          = 3
        inactive_new                  = 4
        inactive_deleted              = 5
        OTHERS                        = 6.

    IF sy-subrc NE 0 OR lt_source IS INITIAL.
      SELECT SINGLE *
        FROM seometarel
        WHERE clsname = @cs_object-object
          AND reltype = '2'
        INTO @DATA(ls_superclass).

      CALL FUNCTION 'SEO_METHOD_GET_SOURCE'
        EXPORTING
          mtdkey                        = VALUE seocpdkey( clsname = ls_superclass-refclsname cpdname = cs_object-obj_method )
        IMPORTING
          source                        = lt_source
        EXCEPTIONS
          _internal_method_not_existing = 1
          _internal_class_not_existing  = 2
          version_not_existing          = 3
          inactive_new                  = 4
          inactive_deleted              = 5
          OTHERS                        = 6.

    ENDIF.

    IF lt_source IS INITIAL.
      RETURN.
    ENDIF.

    cs_object-source = lt_source.

    DELETE cs_object-source WHERE table_line(1) = '*' OR table_line(1) = |"|.

    LOOP AT cs_object-source INTO DATA(ls_source).

      CHECK ls_source IS NOT INITIAL.
      CONDENSE ls_source.
      CHECK ls_source(1) NE '*' AND ls_source(1) NE '"'.

      " Se Tiver Programas Adiciona
      add_program( EXPORTING is_source = ls_source
                   CHANGING  cs_object = cs_object ).

      " Se Tiver Classes Adiciona
      add_class( EXPORTING is_source = ls_source
                 CHANGING  cs_object = cs_object ).

      " Se Tiver Funções Adiciona
      add_function( EXPORTING is_source = ls_source
                    CHANGING  cs_object = cs_object ).

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.
      SORT <fs_dependencies>.
      DELETE ADJACENT DUPLICATES FROM <fs_dependencies>.

    ENDLOOP.

  ENDMETHOD.

  METHOD start_crawler_full_class.

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
      CONDENSE ls_source.
      CHECK ls_source(1) NE '*' AND ls_source(1) NE '"'.

      " Se Tiver Programas Adiciona
      add_program( EXPORTING is_source = ls_source
                   CHANGING  cs_object = cs_object ).

      " Se Tiver Classes Adiciona
      add_class( EXPORTING is_source = ls_source
                 CHANGING  cs_object = cs_object ).

      " Se Tiver Funções Adiciona
      add_function( EXPORTING is_source = ls_source
                    CHANGING  cs_object = cs_object ).

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.
      SORT <fs_dependencies>.
      DELETE ADJACENT DUPLICATES FROM <fs_dependencies>.

    ENDLOOP.

  ENDMETHOD.

  METHOD start_crawler_funct.

    CREATE DATA cs_object-dependencies TYPE TABLE OF ty_dependency.

    DATA: lt_source TYPE TABLE OF rssource.
    DATA: lt_source_new TYPE rsfb_source.
    DATA: lt_import_parameter TYPE TABLE OF rsimp.
    DATA: lt_changing_parameter TYPE TABLE OF rscha.
    DATA: lt_export_parameter TYPE TABLE OF rsexp.
    DATA: lt_tables_parameter TYPE TABLE OF rstbl.
    DATA: lt_exception_list TYPE TABLE OF rsexc.
    DATA: lt_documentation TYPE TABLE OF rsfdo.

    " Buscar Include da FM para garantir as dependencias
    SELECT SINGLE *
      FROM tfdir
      WHERE funcname = @cs_object-object
      INTO @DATA(ls_include).
    IF ls_include IS INITIAL.
      RETURN.

    ELSE.

      DATA: lt_include_fm      TYPE w3_htmltab.
      DATA: lt_include_source  TYPE w3_htmltab.
      DATA: lt_include_sources TYPE w3_htmltab.
      DATA: lt_include_name    TYPE TABLE OF string.
      DATA: lv_include_name    TYPE w3_html.
      READ REPORT ls_include-pname INTO lt_include_fm.
      DELETE lt_include_fm WHERE table_line NS 'INCLUDE z'.
      LOOP AT lt_include_fm INTO DATA(ls_include_fm).
        CONDENSE ls_include_fm.
        SPLIT ls_include_fm AT ' ' INTO TABLE lt_include_name.
        lv_include_name = CONV string( lt_include_name[ 2 ] ).
        REPLACE ALL OCCURRENCES OF '.' IN lv_include_name WITH ''.
        READ REPORT lv_include_name INTO lt_include_source.
        DELETE lt_include_source WHERE table_line(1) = '*' OR table_line(1) = |"|.

        APPEND LINES OF lt_include_source TO lt_include_sources.

        CLEAR: lt_include_source[], lt_include_name[], lv_include_name, ls_include_fm.
      ENDLOOP.

    ENDIF.

    CALL FUNCTION 'RPY_FUNCTIONMODULE_READ_NEW'
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
      CHANGING
        new_source         = lt_source_new
      EXCEPTIONS
        error_message      = 1
        function_not_found = 2
        invalid_name       = 3
        OTHERS             = 4.

    APPEND LINES OF lt_include_sources TO cs_object-source.
    APPEND '    ' TO cs_object-source.
    APPEND LINES OF lt_source_new TO cs_object-source.
    APPEND LINES OF lt_source TO cs_object-source.

    DELETE cs_object-source WHERE table_line(1) = '*' OR table_line(1) = |"|.

    LOOP AT cs_object-source INTO DATA(ls_source).

      CHECK ls_source IS NOT INITIAL.
      CONDENSE ls_source.
      CHECK ls_source(1) NE '*' AND ls_source(1) NE '"'.

      " Se Tiver Programas Adiciona
      add_program( EXPORTING is_source = ls_source
                   CHANGING  cs_object = cs_object ).

      " Se Tiver Classes Adiciona
      add_class( EXPORTING is_source = ls_source
                 CHANGING  cs_object = cs_object ).

      " Se Tiver Funções Adiciona
      add_function( EXPORTING is_source = ls_source
                    CHANGING  cs_object = cs_object ).

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.
      SORT <fs_dependencies>.
      DELETE ADJACENT DUPLICATES FROM <fs_dependencies>.

    ENDLOOP.

    CLEAR: lt_source[].

  ENDMETHOD.

  METHOD start_crawler_cds.

    CREATE DATA cs_object-dependencies TYPE TABLE OF ty_dependency.

    SELECT SINGLE *
      FROM tadir
      WHERE obj_name = @cs_object-object
        AND object   = 'STOB'
      INTO @DATA(ls_tadir_cds).

    IF ls_tadir_cds IS NOT INITIAL.
      SELECT SINGLE ddddlsrc~ddlname,
           ddddlsrc~source,
           ddddlsrct~ddtext
      FROM ddddlsrc
      JOIN ddddlsrct ON ddddlsrc~ddlname = ddddlsrct~ddlname
      WHERE ddddlsrc~ddlname = @cs_object-object
      INTO @DATA(ls_cds).

      SPLIT ls_cds-source AT cl_abap_char_utilities=>cr_lf INTO TABLE cs_object-source.
      DELETE cs_object-source WHERE table_line CS '/*'.

      SELECT SINGLE *
        FROM ddlxsrc_src
        WHERE ddlxname = @cs_object-object
        INTO @DATA(ls_metadata_extension).
      SPLIT ls_metadata_extension-source AT cl_abap_char_utilities=>cr_lf INTO TABLE cs_object-source_extension.

    ELSE.
      " Se não é CDS é Tabela
      DATA lt_table_fields TYPE TABLE OF dd03p.
      CALL FUNCTION 'DDIF_TABL_GET'
        EXPORTING
          name          = CONV ddobjname( cs_object-object )
        TABLES
          dd03p_tab     = lt_table_fields
        EXCEPTIONS
          illegal_input = 1
          OTHERS        = 2.

      cs_object-source = VALUE w3_htmltab( FOR ls IN lt_table_fields ( |CAMPO: { ls-fieldname }; ELEMENTO_DADOS: { ls-rollname }; TIPO: { ls-inttype }| ) ).

    ENDIF.

    LOOP AT cs_object-source INTO DATA(ls_source).

      CONDENSE ls_source.

      CHECK ls_source IS NOT INITIAL.
      CHECK ls_source CS 'projection on' OR
            ls_source CS 'select from' OR
            ls_source CS 'association' OR
            ls_source CS 'join' .

      add_cds( EXPORTING is_source = ls_source
               CHANGING  cs_object = cs_object ).

    ENDLOOP.

  ENDMETHOD.

  METHOD add_cds.

    DATA ls_dependency TYPE ty_dependency.

    DATA lv_cds_name TYPE string.

    IF is_source CS 'projection on' OR is_source CS 'select from'.
      SPLIT is_source AT ' ' INTO TABLE DATA(lt_projections).
      DATA(lv_projections) = lines( lt_projections ).
      lv_cds_name = lt_projections[ lv_projections ].
    ELSEIF is_source CS 'association'.
      SPLIT is_source AT ' ' INTO TABLE DATA(lt_associations).
      lv_cds_name = lt_associations[ 4 ].
    ELSEIF is_source CS 'join'.
    ENDIF.

    CHECK lv_cds_name IS NOT INITIAL.

    APPEND lv_cds_name TO gt_objects_list.
    cl_progress_indicator=>progress_indicate( i_text = |Adicionando Objeto [{ lv_cds_name } - { lines( gt_objects_list ) }.]|
        i_processed          = 1
        i_total              = 1
        i_output_immediately = abap_false ).

    SELECT SINGLE *
      FROM tadir
      WHERE obj_name = @lv_cds_name
        AND object   = 'STOB'
      INTO @DATA(ls_tadir).

    " >>> Inicia o Objeto
    ls_dependency-object   = lv_cds_name.
    TRANSLATE ls_dependency-object TO UPPER CASE.
    ls_dependency-obj_type = COND string( WHEN ls_tadir-object = 'STOB' THEN 'CDS' ELSE 'TABLE' ).

    start_crawler_cds( CHANGING cs_object = ls_dependency ).

    ASSIGN cs_object-dependencies->* TO <fs_dependencies>.

    APPEND ls_dependency TO <fs_dependencies>.

  ENDMETHOD.

  METHOD display_dependencies.

    DATA(lv_json) = /ui2/cl_json=>serialize( gt_objects ).

    CALL TRANSFORMATION sjson2html SOURCE XML lv_json
                               RESULT XML DATA(html).

    IF ch_exp = 'X'.
      EXPORT lv_crawler_json = lv_json TO MEMORY ID 'ZCAR_CRAWLER_JSON'.
    ELSE.
      cl_abap_browser=>show_html( html_string = cl_abap_codepage=>convert_from( html ) ).
    ENDIF.

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
      CONDENSE lv_func_name NO-GAPS.

      IF lv_func_name(1) <> 'Z' OR lv_func_name = cs_object-object.
        RETURN.
      ENDIF.

      APPEND lv_func_name TO gt_objects_list.
      cl_progress_indicator=>progress_indicate( i_text = |Adicionando Objeto [{ lv_func_name } - { lines( gt_objects_list ) }.]|
          i_processed          = 1
          i_total              = 1
          i_output_immediately = abap_false ).

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
      CONDENSE lv_name_object NO-GAPS.

      SELECT SINGLE object
        FROM tadir
        WHERE obj_name = @lv_name_object
          AND object   = 'PROG'
        INTO @DATA(lv_tadir).

      IF ( lv_name_object(1) <> 'Y' AND lv_name_object(1) <> 'Z' ) OR lv_tadir IS INITIAL.
        RETURN.
      ENDIF.
      CLEAR: lv_tadir.

      IF lv_name_object = cs_object-object.
        RETURN.
      ENDIF.

      APPEND lv_name_object TO gt_objects_list.
      cl_progress_indicator=>progress_indicate( i_text = |Adicionando Objeto [{ lv_name_object } - { lines( gt_objects_list ) }.]|
          i_processed          = 1
          i_total              = 1
          i_output_immediately = abap_false ).

      " >>> Inicia o Objeto
      ls_dependency-object   = lv_name_object.
      ls_dependency-obj_type = 'INCLUDE'.

      start_crawler_prog( CHANGING cs_object = ls_dependency ).

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.

      APPEND ls_dependency TO <fs_dependencies>.
    ENDIF.

  ENDMETHOD.

  METHOD add_class.

    CHECK is_source NS 'EXCEPTION'.

    IF is_source CS 'TYPE REF TO'.
      SPLIT is_source AT ' ' INTO TABLE DATA(lt_ref_to).
      DELETE lt_ref_to WHERE table_line IS INITIAL.
      DATA(lv_lines_ref_to) = lines( lt_ref_to ).
      DATA(lv_class_ref_to) = lt_ref_to[ lv_lines_ref_to ].
      REPLACE ALL OCCURRENCES OF '.' IN lv_class_ref_to WITH ''.
      TRANSLATE lv_class_ref_to TO UPPER CASE.
      CONDENSE lv_class_ref_to NO-GAPS.
      APPEND VALUE #( variable = lt_ref_to[ 2 ]
                      class = lv_class_ref_to
                      object = cs_object-object ) TO gt_classes.
    ELSEIF is_source CS '= NEW'.
      SPLIT is_source AT ' ' INTO TABLE DATA(lt_new).
      DELETE lt_new WHERE table_line IS INITIAL.
      DATA(lv_lines_new) = lines( lt_new ).

      SPLIT lt_new[ 1 ] AT '(' INTO TABLE DATA(lt_variable_new).
      DELETE lt_variable_new WHERE table_line IS INITIAL.
      IF lines( lt_variable_new ) = 1.
        DATA(lv_variable) = lt_variable_new[ 1 ].
      ELSE.
        lv_variable = lt_variable_new[ 2 ].
      ENDIF.

      REPLACE ALL OCCURRENCES OF ')' IN lv_variable WITH ''.

      SPLIT is_source AT 'NEW' INTO TABLE DATA(lt_new_split).
      DELETE lt_new_split WHERE table_line IS INITIAL.
      SPLIT lt_new_split[ 2 ] AT '(' INTO TABLE DATA(lt_class_new).
      DELETE lt_class_new WHERE table_line IS INITIAL.
      DATA(lv_class_new) = lt_class_new[ 1 ].
      TRANSLATE lv_class_new TO UPPER CASE.
      CONDENSE lv_class_new NO-GAPS.

      APPEND VALUE #( variable = lv_variable
                      class = lv_class_new
                      object = cs_object-object ) TO gt_classes.
    ENDIF.

    " Caso seja uma chamada de método!!!
    IF ( ( is_source CS '=>' OR is_source CS '->' ) AND ( is_source CS '(' OR is_source CS ')' ) ) OR
       ( is_source CS '(' AND ( is_source CS 'EXPORTING' OR
                                  is_source CS 'CHANGING' OR
                                  is_source CS 'IMPORTING' OR
                                  is_source CS ')' ) ).

      DATA lv_class_name  TYPE string.
      DATA lv_method_name TYPE string.
      DATA ls_dependency TYPE ty_dependency.

      " Chamadas Estáticas
      IF is_source CS '->' AND is_source CS '=>'.
*        zcicl_data=>create( )->get_data( EXPORTING is_interface          = gs_interface
        SPLIT is_source AT '>' INTO TABLE DATA(lt_auto_create).
        lv_class_name = lt_auto_create[ 1 ].

        SPLIT lt_auto_create[ 3 ] AT '(' INTO TABLE lt_auto_create.
        lv_method_name = lt_auto_create[ 1 ].

      ELSEIF is_source CS '->'.
        SPLIT is_source AT '->' INTO TABLE DATA(lt_instance).
        lv_class_name  = lt_instance[ 1 ].
        lv_method_name = lt_instance[ 2 ].

        SPLIT lv_method_name AT '(' INTO TABLE DATA(lt_method_instance).
        lv_method_name = lt_method_instance[ 1 ].

        DATA(ls_object) = VALUE #( gt_classes[ object = cs_object-object variable = lv_class_name ] OPTIONAL ).
        lv_class_name = ls_object-class.

        " Chamadas de Métodos Locais
      ELSEIF is_source CS '(' AND ( is_source CS 'EXPORTING' OR
                                  is_source CS 'CHANGING' OR
                                  is_source CS 'IMPORTING' OR
                                  is_source CS ')' ).
        SPLIT is_source AT '(' INTO TABLE DATA(lt_local_method).
        lv_class_name  = cs_object-object.
        lv_method_name = lt_local_method[ 1 ].

        "Chamadas Instancias
      ELSE.
        SPLIT is_source AT '=>' INTO TABLE DATA(lt_static).
        lv_class_name = lt_static[ 1 ].
        lv_method_name = lt_static[ 2 ].

        SPLIT lv_method_name AT '(' INTO TABLE DATA(lt_method_static).
        lv_method_name = lt_method_static[ 1 ].

      ENDIF.

      REPLACE ALL OCCURRENCES OF '=' IN lv_class_name WITH ''.
      REPLACE ALL OCCURRENCES OF '.' IN lv_class_name WITH ''.
      REPLACE ALL OCCURRENCES OF ',' IN lv_class_name WITH ''.
      REPLACE ALL OCCURRENCES OF '(' IN lv_class_name WITH ''.
      TRANSLATE lv_class_name TO UPPER CASE.
      CONDENSE lv_class_name NO-GAPS.

      REPLACE ALL OCCURRENCES OF '.' IN lv_method_name WITH ''.
      REPLACE ALL OCCURRENCES OF ',' IN lv_method_name WITH ''.
      REPLACE ALL OCCURRENCES OF '(' IN lv_method_name WITH ''.
      TRANSLATE lv_method_name TO UPPER CASE.
      CONDENSE lv_method_name NO-GAPS.

      IF lv_class_name IS INITIAL OR lv_class_name CS '.' OR lv_class_name CS '-' OR lv_class_name(1) NE 'Z'.
        RETURN.
      ENDIF.

      SELECT SINGLE object
        FROM tadir
        WHERE obj_name = @lv_class_name
          AND object   = 'CLAS'
        INTO @DATA(lv_tadir).

      IF ( lv_class_name(1) <> 'Y' AND lv_class_name(1) <> 'Z' ) OR lv_tadir IS INITIAL.
        RETURN.
      ENDIF.
      CLEAR: lv_tadir.

      IF lv_class_name = cs_object-object AND lv_method_name = cs_object-obj_method.
        RETURN.
      ENDIF.

      APPEND lv_class_name TO gt_objects_list.
      cl_progress_indicator=>progress_indicate( i_text = |Adicionando Objeto [{ lv_class_name } - { lines( gt_objects_list ) }.]|
          i_processed          = 1
          i_total              = 1
          i_output_immediately = abap_false ).

      " >>> Inicia o Objeto
      ls_dependency-object     = lv_class_name.
      ls_dependency-obj_type   = 'CLASS'.
      ls_dependency-obj_method = lv_method_name.

      start_crawler_class( CHANGING cs_object = ls_dependency ).

      IF ls_dependency-source IS INITIAL.
        RETURN.
      ENDIF.

      ASSIGN cs_object-dependencies->* TO <fs_dependencies>.

      APPEND ls_dependency TO <fs_dependencies>.

    ENDIF.

  ENDMETHOD.

ENDCLASS.


INITIALIZATION.
  %_p_prog_%_app_%-text = 'Programa: '.
  %_p_clas_%_app_%-text = 'Classe: '.
  %_p_func_%_app_%-text = 'Função: '.
  %_p_cds_%_app_%-text  = 'CDS: '.
  %_ch_exp_%_app_%-text = 'Exportar? '.

START-OF-SELECTION.
  NEW lcl_crawler( iv_prog = p_prog
                   iv_clas = p_clas
                   iv_func = p_func
                   iv_cds  = p_cds ).
