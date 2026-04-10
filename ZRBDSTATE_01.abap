Prog : ZRBDSTATE_01

REPORT zrbdstate_01 MESSAGE-ID b1.

INCLUDE mbdconst.
INCLUDE bdcstaud.

CONSTANTS:
  c_max_idocs TYPE i VALUE '500'.

TABLES: edidc, sscrfields, bdaudstate.

DATA: gs_layout TYPE slis_layout_alv,
      gt_fieldcat TYPE slis_t_fieldcat_alv,
      gs_excluding TYPE slis_t_extab,
      gs_excl_head TYPE slis_extab,
      g_status_set   TYPE slis_formname VALUE 'PF_STATUS_SET',
      g_user_command TYPE slis_formname VALUE 'USER_COMMAND',
      header TYPE lvc_title.

DATA: lv_mail    TYPE ad_smtpadr .
DATA:lt_docnum TYPE zsd_tt_docnum,
     ls_docnum TYPE zsd_str_docnum.
DATA: lv_lines TYPE i.
DATA: lv_msg_text TYPE string,
      lv_lines_c  TYPE c LENGTH 10.

SELECT-OPTIONS:
      s_sndsys FOR bdaudstate-rcv_system.
SELECTION-SCREEN SKIP 1.
SELECT-OPTIONS:
      s_mestyp FOR bdaudstate-mess_type,
      s_mescod FOR bdaudstate-mess_code,
      s_mesfct FOR bdaudstate-mess_funct.
SELECTION-SCREEN SKIP 1.
SELECT-OPTIONS: s_upddat FOR edidc-upddat NO-EXTENSION .

DATA:
      left_date LIKE edidc-upddat,
      left_time LIKE edidc-updtim,
      right_date LIKE edidc-upddat,
      right_time LIKE edidc-updtim,
      t_idoc_control TYPE audit_idoc_control_tab,
      t_idoc_control_all TYPE audit_idoc_control_tab,
      s_idoc_control TYPE audit_idoc_control_t ,
      nothing_to_do,
      resulting_idocs LIKE bdidocs OCCURS 0 WITH HEADER LINE.

DATA: paket TYPE i,
      t_idoc_control_all_max TYPE i,
      t_idoc_control_all_anz TYPE i.

**& ------------
**& -----> Local declaration
**& ------------
TYPES:
  BEGIN OF lty_cdhdr_cat,
    matnr  TYPE matnr,
  END   OF lty_cdhdr_cat.

DATA:
  lt_cdhdr  TYPE TABLE OF cdhdr,
  ls_cdhdr  TYPE cdhdr,
  lv_last_changenr  TYPE cdchangenr,
  lv_docnum         TYPE edi_docnum.

DATA:
 lt_cdhdr_cat  TYPE TABLE OF lty_cdhdr_cat,
 ls_cdhdr_cat  TYPE lty_cdhdr_cat.


START-OF-SELECTION.

  " 1. Récupération de l'adresse email de destination
  SELECT SINGLE low FROM tvarvc
            INTO lv_mail
               WHERE name = 'ZFLOWIE_EMAIL' AND type = 'P' .


**& ----> Last changed documents extracting
**& ---------
  CALL FUNCTION 'ZFLOWIE_GET_LAST_NEW_DOCUMENT'
    EXPORTING
      iv_objectclas = 'IDOC'
    IMPORTING
      ev_changenr   = lv_last_changenr  "/*last number of idoc
    TABLES
      it_cdhdr      = lt_cdhdr.

  lv_docnum =  lv_last_changenr.


*   comparisons are only based on numbers (date and time). This is
*   portable to AS/400.
  SELECT sndprn mestyp mescod mesfct credat cretim docnum status
           FROM edidc INTO TABLE t_idoc_control_all
    WHERE
      docnum > lv_docnum
    AND sndprn IN s_sndsys
    AND mestyp IN s_mestyp
    AND mescod IN s_mescod
    AND mesfct IN s_mesfct
    AND status <> c_status_in_archive_reload
    AND status <> c_status_in_archived
    AND status <> c_status_in_orig_of_edited
  ORDER BY sndprn mestyp mesfct mescod credat cretim.

  IF sy-subrc <> 0.
    nothing_to_do = 'X'.
  ELSE.

    DESCRIBE TABLE t_idoc_control_all LINES t_idoc_control_all_max.

    LOOP AT t_idoc_control_all INTO s_idoc_control.

      APPEND s_idoc_control TO t_idoc_control.
      t_idoc_control_all_anz = t_idoc_control_all_anz + 1.
      paket = paket + 1.
      IF paket = c_max_idocs OR
         t_idoc_control_all_anz = t_idoc_control_all_max.

        CLEAR paket.
        REFRESH t_idoc_control.
      ENDIF.
      ls_docnum-docnum = s_idoc_control-docnum.
      APPEND ls_docnum TO lt_docnum.
    ENDLOOP.

    CALL FUNCTION 'ZIDOC_TO_XML_EMAIL_FLOWIE_01'
       EXPORTING
         iv_email_to = lv_mail
*            iv_subject  = lv_subject
         it_docnums  = lt_docnum .
  ENDIF.

  IF NOT nothing_to_do IS INITIAL.
    MESSAGE i139.
  ELSE.
    DESCRIBE TABLE lt_docnum LINES lv_lines.
    lv_lines_c = lv_lines.
    CONDENSE lv_lines_c.

    CONCATENATE 'Succès : Email envoyé avec'
                lv_lines_c
                'IDocs.'
           INTO lv_msg_text
           SEPARATED BY space.

    MESSAGE lv_msg_text TYPE 'S'.
  ENDIF.

**& ----> Step 4 : Set up last value of IDOC into table
  PERFORM f_set_last_cdhdr_document.

*&---------------------------------------------------------------------*
*&      Form  TIME_INTERVAL_GET
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_LEFT_DATE  text                                            *
*      <--P_LEFT_TIME  text                                            *
*      <--P_RIGHT_DATE  text                                           *
*      <--P_RIGHT_TIME  text                                           *
*----------------------------------------------------------------------*
FORM time_interval_get
  CHANGING
    left_date LIKE edidc-upddat
    left_time LIKE edidc-updtim
    right_date LIKE edidc-upddat
    right_time LIKE edidc-updtim.

  DATA:
    job_name LIKE tbtcjob-jobname,
    job_count LIKE tbtcjob-jobcount,
    job_head LIKE tbtcjob,
    cmp_time LIKE edidc-updtim.

  CALL FUNCTION 'GET_JOB_RUNTIME_INFO'
       IMPORTING
*         eventid                 =
*         eventparm               =
*         external_program_active =
            jobcount                = job_count
            jobname                 = job_name.
*         stepcount               =
*    exceptions
*         no_runtime_info         = 1
*         others                  = 2.

  CALL FUNCTION 'BP_JOB_READ'
    EXPORTING
      job_read_jobcount = job_count
      job_read_jobname  = job_name
      job_read_opcode   = 19
    IMPORTING
      job_read_jobhead  = job_head.
*    tables
*         JOB_READ_STEPLIST     =
*    exceptions
*         invalid_opcode        = 1
*         job_doesnt_exist      = 2
*         job_doesnt_have_steps = 3
*         others                = 4.

*     sdltime is the time when the job was scheduled, this is either the
*     time, when the job was put to the batch list or the time when the
*     predeccessor started

*     substracting 5 minutes from the schedule time is the left border
*     of the time interval
  left_time = job_head-sdltime - 300.  " 300 seconds = 5 minutes
  cmp_time = -300.                                          "23:55
  IF left_time < cmp_time.
    left_date = job_head-sdldate.
  ELSE.
*       date has to changed
    left_date = job_head-sdldate - 1.
  ENDIF.
*     strttime is the time when the job was started
*     substracting 4 minutes from that time is the right border
*     of the time interval, (one minute overlap)
  right_time = job_head-strttime - 240." 240 seconds = 4 minutes
  cmp_time = -240.                                          "23:56
  IF right_time < cmp_time.
    right_date = job_head-strtdate.
  ELSE.
*       date has to be changed
    right_date = job_head-strtdate - 1.
  ENDIF.

ENDFORM.                               " TIME_INTERVAL_GET
*&---------------------------------------------------------------------*
*&      Form  IDOCS_CREATE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM idocs_create
  TABLES
    resulting_idocs STRUCTURE bdidocs
  USING
    idoc_controls TYPE audit_idoc_control_tab.

  CONSTANTS:
    c_filter_mestyp LIKE tbd10-objtype VALUE 'MESTYP'.

  DATA: idoc_control TYPE audit_idoc_control_t,
        receiver_input LIKE bdi_logsys OCCURS 0 WITH HEADER LINE,
        receiver_output LIKE bdi_logsys OCCURS 0 WITH HEADER LINE,
        filter_objects LIKE bdi_fltval OCCURS 0 WITH HEADER LINE,
        to_send TYPE c,
        idoc_info TYPE audit_idoc,
        control_package TYPE audit_idoc_tab.

  LOOP AT idoc_controls INTO idoc_control.
    AT NEW mestyp.
      REFRESH receiver_input.
      receiver_input-logsys = idoc_control-sndprn.
      APPEND receiver_input.

      REFRESH filter_objects.
*     append entry for filter object MESTYP
      filter_objects-objtype = c_filter_mestyp.
      filter_objects-objvalue = idoc_control-mestyp.
      APPEND filter_objects.

      CALL FUNCTION 'ALE_MESTYPE_GET_RECEIVER'
        EXPORTING
          message_type        = c_mestyp_aleaud
        TABLES
          receiver_input      = receiver_input
          receivers           = receiver_output
          filterobject_values = filter_objects.
*     exceptions
*          mestype_not_found        = 1
*          error_in_filterobjects   = 2
*          error_in_ale_customizing = 3
*          others                   = 4.

      IF NOT receiver_output[] IS INITIAL.
        to_send = 'X'.
      ELSE.
        CLEAR to_send.
      ENDIF.
    ENDAT.

    IF NOT to_send IS INITIAL.
      MOVE-CORRESPONDING idoc_control TO idoc_info.
      APPEND idoc_info TO control_package.
    ENDIF.

    AT END OF sndprn.
      IF NOT control_package[] IS INITIAL.
        CALL FUNCTION 'AUDIT_IDOC_CREATE'
          EXPORTING
            rcv_system        = idoc_control-sndprn
          IMPORTING
            idoc_number       = resulting_idocs-docnum
          CHANGING
            idoc_info_records = control_package.
*            exceptions
*                 others            = 1.
        REFRESH control_package.
        IF NOT resulting_idocs IS INITIAL.
          APPEND resulting_idocs.
        ENDIF.
      ENDIF.
    ENDAT.
  ENDLOOP.

ENDFORM.                               " IDOCS_CREATE
*&---------------------------------------------------------------------*
*&      Form  output_list
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_RESULTING_IDOCS  text
*----------------------------------------------------------------------*
FORM output_list.

  header = text-001.
  PERFORM fieldcat_init USING gt_fieldcat[].
  PERFORM layout_init USING gs_layout.
  PERFORM icon_excluding USING gs_excluding.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program       = sy-repid
      i_callback_pf_status_set = g_status_set
      i_callback_user_command  = g_user_command
      i_grid_title             = header
      is_layout                = gs_layout
      it_fieldcat              = gt_fieldcat[]
      it_excluding             = gs_excluding[]
    TABLES
      t_outtab                 = resulting_idocs
    EXCEPTIONS
      program_error            = 1
      OTHERS                   = 2.
  IF sy-subrc <> 0.
  ENDIF.


ENDFORM.                    " output_list
*&---------------------------------------------------------------------*
*&      Form  fieldcat_init
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GT_FIELDCAT[]  text
*----------------------------------------------------------------------*
FORM fieldcat_init  USING  rt_fieldcat
                          TYPE slis_t_fieldcat_alv.

  DATA: ls_fieldcat TYPE slis_fieldcat_alv.

  CLEAR ls_fieldcat.
  ls_fieldcat-fieldname     = 'DOCNUM'.
  ls_fieldcat-seltext_l     = text-200.
  ls_fieldcat-outputlen     = '30'.
  APPEND ls_fieldcat TO  rt_fieldcat.


ENDFORM.                    " fieldcat_init
*&---------------------------------------------------------------------*
*&      Form  layout_init
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GS_LAYOUT  text
*----------------------------------------------------------------------*
FORM layout_init USING rs_layout TYPE slis_layout_alv.
*doubleclick
  rs_layout-f2code            = 'IDOC'.
  rs_layout-colwidth_optimize           = 'X'.
ENDFORM.                    " LAYOUT_INIT
*&---------------------------------------------------------------------*
*&      Form  icon_excluding
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GS_EXCLUDING  text
*----------------------------------------------------------------------*
FORM icon_excluding  USING  p_gs_excluding TYPE slis_t_extab.

  REFRESH  p_gs_excluding[].
  gs_excl_head-fcode = '&VEXCEL'.                  "Excel
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&AQW'.                     "word
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&GRAPH'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&XXL'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&CRBATCH'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&CRTEMPL'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&XINT'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&URL'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&CRDESIG'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&VLOTUS'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&VCRYSTAL'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&OL0'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&XPA'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&OMP'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.

  gs_excl_head-fcode = '&ILT'.
  APPEND gs_excl_head-fcode TO p_gs_excluding.



ENDFORM.                    " ICON_EXCLUDING

*&---------------------------------------------------------------------*
*&      Form  PF_STATUS_SET
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM pf_status_set USING rt_extab TYPE slis_t_extab.
  DATA: l_status LIKE sy-pfkey VALUE 'STANDARD'.
* EXCLUDING FCODES GIVEN BY ABAP LISTVIEWER *
  SET PF-STATUS l_status EXCLUDING rt_extab.
ENDFORM.                    " PF_STATUS_SET
*&---------------------------------------------------------------------*
*&      Form  USER_COMMAND
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM user_command USING rf_ucomm    LIKE sy-ucomm
                        rs_selfield TYPE slis_selfield.

  CASE rf_ucomm.
    WHEN 'IDOC'.
      READ TABLE resulting_idocs INDEX rs_selfield-tabindex.
      IF sy-subrc = 0.
        SUBMIT idoc_tree_control WITH docnum = resulting_idocs-docnum
                             AND RETURN.
      ELSE.
        MESSAGE s010.
*   Bitte Cursor richtig positionieren
      ENDIF.
      CLEAR rf_ucomm.
    WHEN OTHERS.
  ENDCASE.
ENDFORM. " USER_COMMAND
*&---------------------------------------------------------------------*
*&      Form  F_SET_LAST_CDHDR_DOCUMENT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Form  F_SET_LAST_CDHDR_DOCUMENT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM f_set_last_cdhdr_document .

  DATA:
    ls_t_idoc_control TYPE audit_idoc_control_t,
    lv_docnum  TYPE docnum .

  DATA:
   lv_cdobjectv    TYPE cdobjectv.

**& ------> No XML parser is not data
  CHECK t_idoc_control_all[] IS NOT INITIAL.

  SORT t_idoc_control_all BY docnum DESCENDING.


  READ TABLE t_idoc_control_all  INDEX 1  INTO ls_t_idoc_control .
  lv_docnum  = ls_t_idoc_control-docnum.

  lv_cdobjectv = lv_docnum.
**& ----Deleting 0 in the beginning
  SHIFT lv_cdobjectv  LEFT DELETING LEADING '0'.


**& ------> Mise à jour du dernier numéro CDHDR extrait
  CALL FUNCTION 'ZFLOWIE_SET_LAST_DOC_NUMBER'
    EXPORTING
      iv_objectclas    = 'IDOC'     "/*class object
      iv_last_objectid = lv_cdobjectv.  "/*last PO found

ENDFORM.                    " F_SET_LAST_CDHDR_DOCUMENT