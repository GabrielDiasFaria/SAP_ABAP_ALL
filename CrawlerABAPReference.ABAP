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

SELECTION-SCREEN SKIP 1.
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_roles TYPE progname,
              p_subst RADIOBUTTON GROUP r1 DEFAULT 'X',
              p_valid RADIOBUTTON GROUP r1.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
    PARAMETERS: p_enhan  TYPE progname,
                p_enhalv AS CHECKBOX.
  SELECTION-SCREEN END OF BLOCK b3.

  SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-004.
    PARAMETERS: p_exit   TYPE progname,
                p_exialv AS CHECKBOX.
  SELECTION-SCREEN END OF BLOCK b4.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b5 WITH FRAME TITLE TEXT-005.
  PARAMETERS: p_fmoa  TYPE progname MATCHCODE OBJECT fm_search_abadrenv_fmoa.
SELECTION-SCREEN END OF BLOCK b5.

SELECTION-SCREEN BEGIN OF BLOCK b6 WITH FRAME TITLE TEXT-006.
  PARAMETERS: p_com  RADIOBUTTON GROUP r2 DEFAULT 'X',
              p_bud  RADIOBUTTON GROUP r2,
              p_blex AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b6.

SELECTION-SCREEN SKIP 1.
PARAMETERS: ch_exp AS CHECKBOX.


TYPE-POOLS: seoc,
            seop.

TYPES: BEGIN OF ty_dependency,
         object           TYPE string,
         obj_description  TYPE string,
         obj_type         TYPE string,
         obj_method       TYPE string,
         source           TYPE w3_htmltab,
         source_extension TYPE w3_htmltab,
         dependencies     TYPE REF TO data,
         implementation   TYPE string,
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

TYPES:
  BEGIN OF ty_subst,
    field        TYPE string,
    subst        TYPE string,
    value        TYPE string,
    source       TYPE w3_htmltab,
    dependencies TYPE tt_dependency,
  END OF ty_subst,
  tt_subst TYPE STANDARD TABLE OF ty_subst WITH DEFAULT KEY,

  BEGIN OF ty_valid,
    exit         TYPE string,
    msg          TYPE string,
    source       TYPE w3_htmltab,
    dependencies TYPE tt_dependency,
  END OF ty_valid,
  tt_valid TYPE STANDARD TABLE OF ty_valid WITH DEFAULT KEY,

  BEGIN OF ty_stage,
    stage      TYPE string,
    condition  TYPE string,
    validation TYPE string,
    subst      TYPE REF TO data,
    valid      TYPE REF TO data,
    inactive   TYPE abadr_flag,
    derive     TYPE REF TO data,
  END OF ty_stage,
  tt_stage TYPE STANDARD TABLE OF ty_stage WITH DEFAULT KEY,

  BEGIN OF ty_roles,
    type_role TYPE n LENGTH 1, " 1 - Substituição, 2 - Validação, 3 - FMDERIVE
    role      TYPE string,
    stages    TYPE REF TO data,
  END OF ty_roles,

  BEGIN OF ty_derive,
    source       TYPE string,
    target       TYPE string,
    const        TYPE string,
    tabroles     TYPE REF TO data,
    sourcecode   TYPE w3_htmltab,
    dependencies TYPE ty_dependency,
  END OF ty_derive,
  tt_derive TYPE STANDARD TABLE OF ty_derive WITH DEFAULT KEY,

  BEGIN OF ty_derive_roles,
    sour1_from TYPE string,
    sour1_to   TYPE string,
    sour2_from TYPE string,
    sour2_to   TYPE string,
    sour3_from TYPE string,
    sour3_to   TYPE string,
    sour4_from TYPE string,
    sour4_to   TYPE string,
    sour5_from TYPE string,
    sour5_to   TYPE string,
    sour6_from TYPE string,
    sour6_to   TYPE string,
    valid_from TYPE string,
    target1    TYPE string,
    target2    TYPE string,
    target3    TYPE string,
    target4    TYPE string,
    target5    TYPE string,
    target6    TYPE string,
  END OF ty_derive_roles,
  tt_derive_roles TYPE STANDARD TABLE OF ty_derive_roles WITH DEFAULT KEY.

CLASS lcl_crawler DEFINITION.

  PUBLIC SECTION.

    DATA: gt_objects TYPE TABLE OF ty_dependency.

    DATA: gv_is_include TYPE xfeld.

    DATA: gt_objects_list TYPE TABLE OF string.

    DATA: gt_classes TYPE tt_classes.

    METHODS: constructor          IMPORTING iv_prog  TYPE progname
                                            iv_clas  TYPE progname
                                            iv_func  TYPE progname
                                            iv_cds   TYPE progname
                                            iv_roles TYPE progname
                                            iv_enhan TYPE progname
                                            iv_exit  TYPE progname
                                            iv_fmoa  TYPE progname.

    METHODS: start_crawler_prog       CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_cds        CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_class      CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_full_class CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_funct      CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_enhan      CHANGING  cs_object TYPE ty_dependency.
    METHODS: start_crawler_exit       IMPORTING iv_exit          TYPE progname
                                      RETURNING VALUE(re_object) TYPE tt_dependency.
    METHODS: start_crawler_roles      RETURNING VALUE(re_roles) TYPE ty_roles.
    METHODS: start_crawler_derive     IMPORTING iv_derive       TYPE progname
                                      RETURNING VALUE(re_roles) TYPE ty_roles.

    METHODS: add_program  IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.
    METHODS: add_class    IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.
    METHODS: add_function IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.
    METHODS: add_cds      IMPORTING is_source TYPE w3_html
                          CHANGING  cs_object TYPE ty_dependency.

    METHODS: display_dependencies IMPORTING is_data TYPE data.

    METHODS:
      get_substitution_rules RETURNING VALUE(re_roles)  TYPE ty_roles,
      get_validation_rules   RETURNING VALUE(re_roles)  TYPE ty_roles,
      get_source_form        IMPORTING iv_exit          TYPE string
                                       iv_report        TYPE progname
                             RETURNING VALUE(re_source) TYPE w3_htmltab,
      get_source_dependence  IMPORTING is_source       TYPE w3_htmltab
                             RETURNING VALUE(re_depen) TYPE tt_dependency,
      get_source_implement CHANGING  cs_object TYPE ty_dependency,
      get_derive_table IMPORTING iv_table        TYPE abadr_value
                       RETURNING VALUE(re_table) TYPE tt_derive_roles,
      display_enhancement,
      display_exit.

ENDCLASS.

CLASS lcl_crawler IMPLEMENTATION.

  METHOD constructor.
    " >>> Inicia o Objeto
    DATA ls_objects LIKE LINE OF gt_objects.
    " <<< Inicia o Objeto

    CASE abap_true.
      WHEN p_enhalv.
        display_enhancement( ).
      WHEN p_exialv.
        display_exit( ).
      WHEN OTHERS.
    ENDCASE.

    IF NOT iv_roles IS INITIAL.
      "Se for regra de substituição ou validação
      DATA(lt_roles) = start_crawler_roles( ).
      display_dependencies( lt_roles ).

    ELSEIF NOT iv_exit IS INITIAL AND ls_objects-source IS INITIAL.
      "Exit's
      ls_objects-implementation = iv_exit.
      ls_objects-obj_type       = 'EXIT'.
      display_dependencies( start_crawler_exit( iv_exit ) ).

    ELSEIF NOT iv_fmoa IS INITIAL.
      "Estratégia de Derivação
      DATA(lt_fmoa) = start_crawler_derive( iv_fmoa ).
      display_dependencies( lt_fmoa ).
    ELSEIF NOT p_blex IS INITIAL.

      CASE abap_true.
        WHEN p_bud.
          DATA(l_blex) = CONV progname( 'BUD30' ).
        WHEN p_com.
          l_blex = CONV progname( 'COM30' ).
        WHEN OTHERS.
      ENDCASE.
      "Estratégia de Derivação
      DATA(lt_blex) = start_crawler_derive( l_blex ).
      display_dependencies( lt_blex ).
    ELSE.
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
        ls_objects-object   = iv_func.
        ls_objects-obj_type = 'FUNCTION'.
        start_crawler_funct( CHANGING cs_object = ls_objects ).
      ENDIF.

      IF iv_cds IS NOT INITIAL AND ls_objects-source IS INITIAL.
        ls_objects-object   = iv_cds.
        ls_objects-obj_type = 'CDS'.
        start_crawler_cds( CHANGING cs_object = ls_objects ).
      ENDIF.

      IF iv_enhan IS NOT INITIAL AND ls_objects-source IS INITIAL.
        ls_objects-implementation = iv_enhan.
        ls_objects-obj_type       = 'ENHANCEMENT'.
        start_crawler_enhan( CHANGING cs_object = ls_objects ).
      ENDIF.

      APPEND ls_objects TO gt_objects.

      IF NOT gt_objects IS INITIAL.
        display_dependencies( gt_objects ).
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD start_crawler_prog.

    ">>> Inicia o Objeto
    DATA lv_object_name TYPE progname.
    lv_object_name = CONV progname( cs_object-object ).
    READ REPORT lv_object_name INTO cs_object-source.

    IF cs_object-source IS INITIAL.
      " Buscamos pela Transação
      SELECT SINGLE *
        FROM tstc
        WHERE tcode = @cs_object-object
        INTO @DATA(ls_tcode).

      IF ls_tcode IS NOT INITIAL.
        cs_object-object = ls_tcode-pgmna.
        lv_object_name = CONV progname( cs_object-object ).
        READ REPORT lv_object_name INTO cs_object-source.
      ENDIF.

    ENDIF.

    SELECT SINGLE text
      FROM trdirt
      WHERE name = @cs_object-object
      INTO @cs_object-obj_description.

    DELETE cs_object-source WHERE table_line(1) = '*' OR table_line(1) = |"|.
    DELETE cs_object-source WHERE table_line = ''.

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
        INTO @DATA(ls_class_nv2).

      CALL FUNCTION 'SEO_METHOD_GET_SOURCE'
        EXPORTING
          mtdkey                        = VALUE seocpdkey( clsname = ls_class_nv2-refclsname cpdname = cs_object-obj_method )
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
          WHERE clsname = @ls_class_nv2-refclsname
            AND reltype = '2'
          INTO @DATA(ls_class_nv3).

        CALL FUNCTION 'SEO_METHOD_GET_SOURCE'
          EXPORTING
            mtdkey                        = VALUE seocpdkey( clsname = ls_class_nv3-refclsname cpdname = cs_object-obj_method )
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
            WHERE clsname = @ls_class_nv3-refclsname
              AND reltype = '2'
            INTO @DATA(ls_class_nv4).

          CALL FUNCTION 'SEO_METHOD_GET_SOURCE'
            EXPORTING
              mtdkey                        = VALUE seocpdkey( clsname = ls_class_nv4-refclsname cpdname = cs_object-obj_method )
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

      ENDIF.

    ENDIF.

    IF lt_source IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_clskey) = VALUE seoclskey( clsname = cs_object-object ).
    DATA ls_class TYPE seoc_class_r.
    CALL FUNCTION 'SEO_CLASS_READ'
      EXPORTING
        clskey          = ls_clskey
        master_language = sy-langu
      IMPORTING
        class           = ls_class.

    cs_object-obj_description = ls_class-descript.

    cs_object-source = lt_source.

    DELETE cs_object-source WHERE table_line(1) = '*' OR table_line(1) = |"|.
    DELETE cs_object-source WHERE table_line = ''.

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
    DELETE cs_object-source WHERE table_line = ''.

    DATA(ls_clskey) = VALUE seoclskey( clsname = cs_object-object ).
    DATA ls_class TYPE seoc_class_r.
    CALL FUNCTION 'SEO_CLASS_READ'
      EXPORTING
        clskey          = ls_clskey
        master_language = sy-langu
      IMPORTING
        class           = ls_class.

    cs_object-obj_description = ls_class-descript.

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

    SELECT SINGLE stext
      FROM tftit
      WHERE funcname = @cs_object-object
      INTO @cs_object-obj_description.

    DELETE cs_object-source WHERE table_line(1) = '*' OR table_line(1) = |"|.
    DELETE cs_object-source WHERE table_line = ''.

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
      JOIN ddddlsrct ON ddddlsrc~ddlname     = ddddlsrct~ddlname
                    AND ddddlsrct~ddlanguage = @sy-langu
      WHERE ddddlsrc~ddlname = @cs_object-object
      INTO @DATA(ls_cds).

      cs_object-obj_description = ls_cds-ddtext.

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

    IF is_source CS 'projection on' OR is_source CS 'select from z'.
      SPLIT is_source AT 'as' INTO TABLE DATA(lt_get_as).
      SPLIT lt_get_as[ 2 ] AT ' ' INTO TABLE DATA(lt_projections).
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

  METHOD start_crawler_roles.
    CASE abap_true.
      WHEN p_subst.
        re_roles = get_substitution_rules( ).
      WHEN p_valid.
        re_roles = get_validation_rules( ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.

  METHOD start_crawler_enhan.

    DATA: l_width TYPE i.

    FIELD-SYMBOLS: <fs_dependecy> TYPE tt_dependency.

    SELECT SINGLE *
      FROM enhheader
      INTO @DATA(ls_enhheader)
      WHERE enhname = @cs_object-implementation.

    CHECK sy-subrc IS INITIAL.

    IF ls_enhheader-enhtooltype = 'BADI_IMPL'.
      SELECT SINGLE *
        FROM enhobj
        INTO @DATA(ls_enhobj)
        WHERE enhname = @ls_enhheader-enhname
          AND obj_type = 'CLAS'.
      IF sy-subrc IS INITIAL.
        cs_object-object = ls_enhobj-obj_name.
        start_crawler_full_class( CHANGING cs_object = cs_object ).
      ENDIF.

    ELSE.
      SELECT SINGLE *
        FROM enhincinx
        INTO @DATA(ls_enhincinx)
        WHERE enhname = @ls_enhheader-enhname.

      READ REPORT ls_enhincinx-enhinclude STATE 'A' INTO cs_object-source MAXIMUM WIDTH INTO l_width.
      CREATE DATA cs_object-dependencies TYPE tt_dependency.
      cs_object-object = ls_enhincinx-programname.

      cs_object-dependencies->* = get_source_dependence( cs_object-source ).

    ENDIF.
  ENDMETHOD.

  METHOD start_crawler_exit.
    DATA: ls_objects TYPE ty_dependency,
          l_include  TYPE rs38l-include.

    SELECT proj~name, comp~name AS ext, comp~typ, comp~member, comp~modtext
      FROM modactt AS proj
      LEFT OUTER JOIN modsapview AS comp
      ON proj~member = comp~name
      INTO TABLE @DATA(lt_exit)
      WHERE proj~name = @iv_exit
        AND proj~member <> @abap_false
        AND comp~member <> @abap_false
        AND comp~sprsl = @sy-langu.

    LOOP AT lt_exit INTO DATA(ls_exit).
      CASE ls_exit-typ.
        WHEN 'E'.
          CALL FUNCTION 'FUNCTION_EXISTS'
            EXPORTING
              funcname           = CONV rs38l_fnam( ls_exit-member )
            IMPORTING
              include            = l_include
            EXCEPTIONS
              function_not_exist = 1
              OTHERS             = 2.
          IF sy-subrc <> 0.
* Implement suitable error handling here
          ENDIF.
          ls_objects-object   = l_include.
          ls_objects-implementation = |Projeto: { ls_exit-name } - Ampliação: { ls_exit-ext }|.
          ls_objects-obj_type = 'PROGRAM'.
          start_crawler_prog( CHANGING cs_object = ls_objects ).
        WHEN OTHERS.
      ENDCASE.

      APPEND ls_objects TO re_object.
      CLEAR: ls_objects.

    ENDLOOP.
  ENDMETHOD.

  METHOD start_crawler_derive.
    DATA: l_strategy      TYPE psm_abadr_strategy,
          ls_roles        TYPE ty_roles,
          ls_stages       TYPE ty_stage,
          ls_derive       TYPE ty_derive,
          ls_derive_roles TYPE ty_derive_roles,
          lt_derive_roles TYPE tt_derive_roles,
          ls_objects      LIKE LINE OF gt_objects.

    FIELD-SYMBOLS: <fs_tabroles> TYPE tt_derive_roles,
                   <fs_stages>   TYPE tt_stage,
                   <fs_derive>   TYPE tt_derive.

    SELECT SINGLE *
      FROM tabadrh
      INTO @DATA(ls_tabadrh)
      WHERE abadrenv = @iv_derive.

    IF sy-subrc IS INITIAL.
      SELECT SINGLE *
        FROM buavckedrenvt
        INTO @DATA(ls_drenvt)
        WHERE applclass   = @ls_tabadrh-applclass
          AND subclass    = @ls_tabadrh-subclass
          AND kedrstratid = @ls_tabadrh-abadrstratid
          AND kedrenv     = @ls_tabadrh-abadrenv
          AND langu       = @sy-langu.
    ENDIF.

    DATA(l_key) = VALUE psm_abadr_strategy_key( appl        = ls_tabadrh-applclass
                                                subclass    = ls_tabadrh-subclass
                                                strategy_id = ls_tabadrh-abadrstratid
                                                env         = ls_tabadrh-abadrenv ).

    CALL FUNCTION 'ABADR_GET_STRATEGY_DETAILS'
      EXPORTING
        i_key               = l_key
        i_view_mode         = 'A'
        i_use_init_env_exit = abap_true
      IMPORTING
        e_strategy          = l_strategy
      EXCEPTIONS
        strategy_not_found  = 1
        OTHERS              = 2.
    IF sy-subrc <> 0.
* Implement suitable error handling here
    ENDIF.

    re_roles-type_role = 3.
    IF NOT ls_drenvt-kedrenvtext IS INITIAL.
      re_roles-role = |Estratégia Derivação: { ls_tabadrh-abadrenv } - { ls_drenvt-kedrenvtext }|.
    ELSE.
      re_roles-role = |Estratégia Derivação: { ls_tabadrh-abadrenv } - Lçto. Valores Reais/Comprom.|.
    ENDIF.

    CREATE DATA re_roles-stages TYPE STANDARD TABLE OF ty_stage.

    LOOP AT l_strategy-tab_steps INTO DATA(ls_steps).
      CREATE DATA ls_stages-derive TYPE STANDARD TABLE OF ty_derive.

      "Etapas
      ls_stages-stage = |Etapa: { ls_steps-step_no }| .
      ls_stages-inactive = ls_steps-is_inactive.

      "Condições
      LOOP AT ls_steps-tab_conditions INTO DATA(ls_cond).

        IF ls_cond-field_1-use_constant IS INITIAL.
          DATA(l_field1) = CONV char50( ls_cond-field_1-name-fieldname ).
        ELSE.
          IF NOT ls_cond-field_1-constant_value IS INITIAL.
            l_field1 = ls_cond-field_1-constant_value.
          ELSE.
            l_field1 = |' '|.
          ENDIF.

        ENDIF.

        IF ls_cond-field_2-use_constant IS INITIAL.
          DATA(l_field2) = CONV char50( ls_cond-field_2-name-fieldname ).
        ELSE.
          IF NOT ls_cond-field_2-constant_value IS INITIAL.
            l_field2 = ls_cond-field_2-constant_value.
          ELSE.
            l_field2 = |' '|.
          ENDIF.
        ENDIF.

        IF sy-tabix = 1.
          ls_stages-condition = |{ l_field1 } { ls_cond-operator } { l_field2 }|.
        ELSE.
          ls_stages-condition = |{ ls_stages-condition } { ls_cond-chain_operator } { l_field1 } { ls_cond-operator } { l_field2 }|.
        ENDIF.

        CLEAR: l_field1, l_field2.
      ENDLOOP.

      LOOP AT ls_steps-tab_sources INTO DATA(ls_source).
        IF NOT ls_source-field-use_constant IS INITIAL.
          ls_derive-const = ls_source-field-use_constant.
          ls_derive-source = ls_source-field-constant_value.
        ELSE.
          ls_derive-source = |{ ls_derive-source } { ls_source-field-name-fieldname }|.
        ENDIF.
      ENDLOOP.

      LOOP AT ls_steps-tab_targets INTO DATA(ls_target).
        IF NOT ls_target-field-name-fieldname IS INITIAL.
          ls_derive-target = |{ ls_derive-target } { ls_target-field-name-fieldname }|.
        ENDIF.
      ENDLOOP.

      CASE ls_steps-method.
        WHEN 'DRULE'.
          CREATE DATA ls_derive-tabroles TYPE TABLE OF ty_derive_roles.

          ls_derive-tabroles->* = get_derive_table( ls_steps-param_1 ).
        WHEN 'FUNC'.
          ls_objects-object   = ls_steps-param_1.
          ls_objects-obj_type = 'FUNCTION'.
          start_crawler_funct( CHANGING cs_object = ls_objects ).

          ls_derive-dependencies = ls_objects.
        WHEN OTHERS.
      ENDCASE.

      ASSIGN ls_stages-derive->* TO <fs_derive>.
      IF <fs_derive> IS ASSIGNED.
        APPEND ls_derive TO <fs_derive>.
      ENDIF.

      ASSIGN re_roles-stages->* TO <fs_stages>.
      IF <fs_stages> IS ASSIGNED.
        APPEND ls_stages TO <fs_stages>.
      ENDIF.

      CLEAR: ls_derive, ls_stages.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_substitution_rules.
    DATA: ls_roles  TYPE ty_roles,
          ls_stages TYPE ty_stage,
          ls_subst  TYPE ty_subst.

    FIELD-SYMBOLS: <fs_subst>  TYPE tt_subst,
                   <fs_stages> TYPE tt_stage.

    SELECT SINGLE gb92~substid, gb31t~valeventxt
          FROM gb92
          INNER JOIN gb31
          ON  gb92~boolclass = gb31~rclass
          INNER JOIN gb31t
          ON gb31~valuser = gb31t~valuser
          AND gb31~valevent = gb31t~valevent
          AND gb92~subsclass = gb31~wclass
          AND gb31t~spras = @sy-langu
          INTO @DATA(ls_92)
          WHERE substid = @p_roles.

    SELECT 921~substid, 921~subseqnr, 921~condid, 921t~substext, 901~boolexp
      FROM gb921 AS 921
      LEFT OUTER JOIN gb921t AS 921t
      ON 921~substid = 921t~subsid
      AND 921~subseqnr = 921t~subseqnr
      LEFT OUTER JOIN gb901 AS 901
      ON 921~condid = 901~boolid
      INTO TABLE @DATA(lt_921)
      WHERE substid = @p_roles.

    IF sy-subrc IS INITIAL.
      SELECT *
        FROM gb922
        INTO TABLE @DATA(lt_922)
        FOR ALL ENTRIES IN @lt_921
        WHERE substid = @lt_921-substid
          AND subseqnr = @lt_921-subseqnr.

      SORT lt_922 BY substid ASCENDING subseqnr ASCENDING.
    ENDIF.

    re_roles-type_role = 1.
    re_roles-role = | Regra: { ls_92-substid } - { ls_92-valeventxt } |.
    CREATE DATA re_roles-stages TYPE STANDARD TABLE OF ty_stage.

    LOOP AT lt_922 INTO DATA(ls_922).
      CREATE DATA ls_stages-subst TYPE STANDARD TABLE OF ty_subst.

      "Etapas
      ls_stages-stage = | Etapa: { ls_922-subseqnr } - { lt_921[ substid = ls_922-substid subseqnr = ls_922-subseqnr ]-substext } | .

      "Condições
      LOOP AT lt_921 INTO DATA(ls_921) WHERE substid = ls_922-substid
                                         AND subseqnr = ls_922-subseqnr
                                         AND NOT boolexp IS INITIAL.
        ls_stages-condition = | { ls_stages-condition }{ ls_921-boolexp } |.
      ENDLOOP.

      "Substituições
      IF NOT ls_922-substab IS INITIAL.
        ls_subst-field = | { ls_922-substab }-{ ls_922-subsfield } |.
      ENDIF.

      IF NOT ls_922-subsval IS INITIAL.
        ls_subst-subst = 'Valor constante'.
        ls_subst-value = ls_922-subsval.
      ELSEIF NOT ls_922-exitsubst IS INITIAL.
        ls_subst-subst = 'Exit'.
        ls_subst-value = ls_922-exitsubst.
        TRANSLATE ls_subst-value TO LOWER CASE.
        ls_subst-source = get_source_form( EXPORTING iv_exit = ls_subst-value
                                                     iv_report = 'ZFIRGGBS000' ).
        ls_subst-dependencies = get_source_dependence( ls_subst-source ).

      ELSE.
        ls_subst-subst = 'Campo'.
        ls_subst-value = | { ls_922-tabsubst }-{ ls_922-filedsub } |.
      ENDIF.

      ASSIGN ls_stages-subst->* TO <fs_subst>.
      IF <fs_subst> IS ASSIGNED.
        APPEND ls_subst TO <fs_subst>.
        CLEAR ls_subst.
      ENDIF.

      ASSIGN re_roles-stages->* TO <fs_stages>.
      IF <fs_stages> IS ASSIGNED.
        APPEND ls_stages TO <fs_stages>.
        CLEAR: ls_stages.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_validation_rules.
    DATA: ls_roles    TYPE ty_roles,
          ls_stages   TYPE ty_stage,
          ls_valid    TYPE ty_valid,
          ls_bapiret1 TYPE bapiret1.

    DATA: l_msgno TYPE syst_msgno.

    FIELD-SYMBOLS: <fs_valid>  TYPE tt_valid,
                   <fs_stages> TYPE tt_stage.

    SELECT SINGLE gb93~valid, gb93~msgid, gb31t~valeventxt
      FROM gb93
      INNER JOIN gb31
      ON  gb93~boolclass = gb31~rclass
      INNER JOIN gb31t
      ON gb31~valuser = gb31t~valuser
      AND gb31~valevent = gb31t~valevent
      AND gb31t~spras = @sy-langu
      INTO @DATA(ls_93)
      WHERE valid = @p_roles.

    IF sy-subrc IS INITIAL.
      SELECT *
        FROM gb931
        INTO TABLE @DATA(lt_931)
        WHERE valid = @ls_93-valid.

      IF sy-subrc IS INITIAL.
        SELECT *
          FROM gb901
          INTO TABLE @DATA(lt_cond)
          FOR ALL ENTRIES IN @lt_931
          WHERE boolid = @lt_931-condid.

        SELECT *
          FROM gb901
          INTO TABLE @DATA(lt_valid)
          FOR ALL ENTRIES IN @lt_931
          WHERE boolid = @lt_931-checkid.
      ENDIF.
    ENDIF.

    re_roles-type_role = 2.
    re_roles-role = | Regra: { ls_93-valid } - { ls_93-valeventxt } |.
    CREATE DATA re_roles-stages TYPE STANDARD TABLE OF ty_stage.

    LOOP AT lt_931 INTO DATA(ls_931).
      CREATE DATA ls_stages-valid TYPE STANDARD TABLE OF ty_valid.

      "Etapas
      ls_stages-stage = | Etapa: { ls_931-valseqnr } | .

      "Condições
      LOOP AT lt_cond INTO DATA(ls_cond) WHERE boolid = ls_931-condid
                                           AND NOT boolexp IS INITIAL.
        ls_stages-condition = | { ls_stages-condition }{ ls_cond-boolexp } |.
      ENDLOOP.

      "Validação
      "Condição de validação ou Exit
      IF line_exists( lt_valid[ boolid = ls_931-checkid ] ).
        IF lt_valid[ boolid = ls_931-checkid ]-boolexp+1(1) <> '='.
          LOOP AT lt_valid INTO DATA(ls_valid2) WHERE boolid = ls_931-checkid
                                                 AND NOT boolexp IS INITIAL.
            ls_stages-validation = | { ls_stages-validation }{ ls_valid2-boolexp } |.
          ENDLOOP.
        ELSE.
          ls_valid-exit = lt_valid[ boolid = ls_931-checkid ]-boolexp+2 .
          TRANSLATE ls_valid-exit TO LOWER CASE.
          ls_valid-source = get_source_form( EXPORTING iv_exit = ls_valid-exit
                                                       iv_report = 'ZFIRGGBR000' ).
          ls_valid-dependencies = get_source_dependence( ls_valid-source ).
        ENDIF.
      ENDIF.

      "Mensagem
      IF NOT ls_931-valmsg IS INITIAL  .

        IF NOT ls_931-msgtab1 IS INITIAL.
          DATA(l_var1) = CONV syst_msgv( | < { ls_931-msgtab1 } - { ls_931-msgfield1 } > | ).
        ENDIF.
        IF NOT ls_931-msgtab2 IS INITIAL.
          DATA(l_var2) = CONV syst_msgv( | < { ls_931-msgtab2 } - { ls_931-msgfield2 } > | ).
        ENDIF.
        IF NOT ls_931-msgtab3 IS INITIAL.
          DATA(l_var3) = CONV syst_msgv( | < { ls_931-msgtab3 } - { ls_931-msgfield3 } > | ).
        ENDIF.
        IF NOT ls_931-msgtab4 IS INITIAL.
          DATA(l_var4) = CONV syst_msgv( | < { ls_931-msgtab4 } - { ls_931-msgfield4 } > | ).
        ENDIF.

        l_msgno = ls_931-valmsg.
        CALL FUNCTION 'BALW_BAPIRETURN_GET1'
          EXPORTING
            type       = ls_931-valsevere
            cl         = ls_93-msgid
            number     = l_msgno
            par1       = l_var1
            par2       = l_var2
            par3       = l_var3
            par4       = l_var4
          IMPORTING
            bapireturn = ls_bapiret1.

        ls_valid-msg = ls_bapiret1-message.
      ENDIF.

      ASSIGN ls_stages-valid->* TO <fs_valid>.
      IF <fs_valid> IS ASSIGNED.
        APPEND ls_valid TO <fs_valid>.
        CLEAR ls_valid.
      ENDIF.

      ASSIGN re_roles-stages->* TO <fs_stages>.
      IF <fs_stages> IS ASSIGNED.
        APPEND ls_stages TO <fs_stages>.
        CLEAR: ls_stages.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD display_dependencies.
    DATA(lv_json) = /ui2/cl_json=>serialize( EXPORTING data = is_data
                                                       compress = abap_true ).

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

      IF ( lv_func_name(1) <> 'Z' AND lv_func_name(1) <> 'Y' ) OR lv_func_name = cs_object-object.
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

*      DATA(lv_name_object) = lt_object[ lv_last_line_include ].
      DATA(lv_name_object) = lt_object[ 2 ].
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

  METHOD get_source_form.
    DATA: lt_source TYPE w3_htmltab.

    DATA(l_exit) = |FORM { iv_exit }|.
    READ REPORT iv_report INTO lt_source.

    DELETE lt_source WHERE table_line(1) = '*' OR table_line(1) = |"|.

    FIND l_exit IN TABLE lt_source MATCH LINE DATA(l_line).
    IF sy-subrc IS INITIAL.
      DO.
        APPEND lt_source[ l_line ] TO re_source.

        FIND 'ENDFORM' IN lt_source[ l_line ].
        IF sy-subrc IS INITIAL.
          EXIT.
        ENDIF.

        ADD 1 TO l_line.
      ENDDO.
    ENDIF.
  ENDMETHOD.

  METHOD get_source_dependence.
    DATA: ls_dependency TYPE ty_dependency.

    DATA(lt_source) = is_source.

    DELETE lt_source WHERE table_line(1) = '*' OR table_line(1) = |"|.

    CREATE DATA ls_dependency-dependencies TYPE TABLE OF ty_dependency.
    "<<< Inicia o Objeto

    LOOP AT lt_source INTO DATA(ls_source).

      CHECK ls_source IS NOT INITIAL.
      CONDENSE ls_source.
      CHECK ls_source(1) NE '*' AND ls_source(1) NE '"'.

      " Se Tiver Classes Adiciona
      add_program( EXPORTING is_source = ls_source
                   CHANGING  cs_object = ls_dependency ).

      " Se Tiver Programas Adiciona
      add_class( EXPORTING is_source = ls_source
                 CHANGING  cs_object = ls_dependency ).

      " Se Tiver Funções Adiciona
      add_function( EXPORTING is_source = ls_source
                    CHANGING  cs_object = ls_dependency ).

      ASSIGN ls_dependency-dependencies->* TO <fs_dependencies>.
      SORT <fs_dependencies>.
      DELETE ADJACENT DUPLICATES FROM <fs_dependencies>.
    ENDLOOP.

    re_depen = ls_dependency-dependencies->*.

  ENDMETHOD.

  METHOD get_source_implement.
    DATA(lt_source) = cs_object-source.

    REFRESH cs_object-source.

*    DATA(l_exit) = |FORM { iv_exit }|.
*    READ REPORT iv_report INTO lt_source.

    DELETE lt_source WHERE table_line(1) = '*' OR table_line(1) = |"|.

    FIND cs_object-implementation IN TABLE lt_source MATCH LINE DATA(l_line).
    IF sy-subrc IS INITIAL.
      DO.
        APPEND lt_source[ l_line ] TO cs_object-source.

        FIND 'ENDENHANCEMENT' IN lt_source[ l_line ].
        IF sy-subrc IS INITIAL.
          EXIT.
        ENDIF.

        ADD 1 TO l_line.
      ENDDO.
    ENDIF.
  ENDMETHOD.

  METHOD get_derive_table.
    DATA: lv_tabname TYPE tabname.

    DATA: lo_tabtype     TYPE REF TO cl_abap_tabledescr,
          lo_struct_type TYPE REF TO cl_abap_structdescr,
          lr_data        TYPE REF TO data,
          lt_comp_tab    TYPE cl_abap_structdescr=>component_table,
          ls_comp_fld    TYPE cl_abap_structdescr=>component.

    FIELD-SYMBOLS: <fs_tab>    TYPE ANY TABLE,
                   <fs_struct> TYPE any.

    lv_tabname = iv_table.  " Give tab name from your dropdown select

    lo_struct_type ?= cl_abap_typedescr=>describe_by_name( lv_tabname ).
    lt_comp_tab  = lo_struct_type->get_components( ).

    lo_struct_type = cl_abap_structdescr=>create( lt_comp_tab ).
    lo_tabtype     = cl_abap_tabledescr=>create( lo_struct_type ).

    CREATE DATA lr_data TYPE HANDLE lo_tabtype.
    ASSIGN lr_data->* TO <fs_tab>.

* dynamic select
    SELECT *
      FROM (lv_tabname)
      INTO CORRESPONDING FIELDS OF TABLE <fs_tab>.

    re_table = CORRESPONDING #( lr_data->* ).
  ENDMETHOD.

  METHOD display_enhancement.
    SELECT DISTINCT enhname
      FROM enhheader
      INTO TABLE @DATA(lt_enhan)
      WHERE enhname LIKE 'Z%'.

    cl_demo_output=>display_data( lt_enhan ).
  ENDMETHOD.

  METHOD display_exit.

    SELECT proj~name, comp~name AS ext, comp~member,
      CASE WHEN comp~typ = 'E' THEN 'Exit de função'
           WHEN comp~typ = 'S' THEN 'Telas'
           WHEN comp~typ = 'T' THEN 'Tabelas'
           WHEN comp~typ = 'C' THEN 'Code CUA'
      END AS type
      FROM modactt AS proj
      LEFT OUTER JOIN modsapview AS comp
      ON proj~member = comp~name
      INTO TABLE @DATA(lt_exit)
      WHERE proj~member <> @abap_false
        AND comp~member <> @abap_false
        AND comp~sprsl = @sy-langu.

    SORT lt_exit BY name ASCENDING ext ASCENDING.

    cl_demo_output=>display_data( lt_exit ).
  ENDMETHOD.

ENDCLASS.

INITIALIZATION.
  %_p_prog_%_app_%-text   = 'Programa: '.
  %_p_clas_%_app_%-text   = 'Classe: '.
  %_p_func_%_app_%-text   = 'Função: '.
  %_p_cds_%_app_%-text    = 'CDS: '.
  %_p_roles_%_app_%-text  = 'Regra: '.
  %_p_subst_%_app_%-text  = 'Substituição: '.
  %_p_valid_%_app_%-text  = 'Validação: '.
  %_p_enhan_%_app_%-text  = 'Enhancement: '.
  %_p_exit_%_app_%-text   = 'Exit: '.
  %_p_fmoa_%_app_%-text   = 'Estratégia de Derivação: '.
  %_p_bud_%_app_%-text    = 'Lçtos.orçamento: '.
  %_p_com_%_app_%-text    = 'Lçto.valores reais/comprom.: '.
  %_p_blex_%_app_%-text   = 'Gerar JSON '.
  %_ch_exp_%_app_%-text   = 'Exportar? '.

START-OF-SELECTION.
  NEW lcl_crawler( iv_prog    = p_prog
                   iv_clas    = p_clas
                   iv_func    = p_func
                   iv_cds     = p_cds
                   iv_roles   = p_roles
                   iv_enhan   = p_enhan
                   iv_exit    = p_exit
                   iv_fmoa    = p_fmoa ).
