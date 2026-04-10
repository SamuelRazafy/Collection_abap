ZMM_PRODUCT_CAT

*&---------------------------------------------------------------------*
*& Report ZMM_PRODUCT_CAT                                              *
*&---------------------------------------------------------------------*
*               *** Catalogue de produits ***                          *
*                                                                      *
* SAP Name            :  ZMM_PRODUCT_CAT                               *
*                                                                      *
* Package             :  ZFI_001                                       *
*                                                                      *
* Title               :  Programme Pour Le Catalogue de Produits       *
*                                                                      *
* Module              :  MM                                            *
*                                                                      *
* Author              :  SAPERP SOLUTION                               *
*                                                                      *
* Creation date       :  19.02.2026                                    *
*                                                                      *
* Transaction code    :  xxx                                           *
*                                                                      *
*----------------------------------------------------------------------*
*                 *** Modifications history ***                        *
*                                                                      *
* Date        User ID               Transport / Description            *
* ==========  ====================  ================================== *
* 19.02.2026  FLOWIETECH            DEVK904294       Creation          *
* 24.03.2026  FLOWIETECH            DEVK904294       Modification xml  *
*----------------------------------------------------------------------*

REPORT  ZMM_PRODUCT_CAT.

include ZMM_PRODUCT_CAT_data.  " Include pour les données
include ZMM_PRODUCT_CAT_scr.   " Include pour l'écran
include ZMM_PRODUCT_CAT_forms. " Include pour le programme

START-OF-SELECTION.

**& ----> Step 1 : Data main extraction
  PERFORM f_get_data.

**& ----> Step 2 : Complete data
  PERFORM fill_data.

**& ----> Step 3 : Convert XML File to Binary File and send mail
  PERFORM f_xml_batch USING lv_batch_size.  " Génération du fichier xml, enregistrement dans AL11, Envoie par mail

**& ----> Step 4 : Set up last value of material into table
  PERFORM f_set_last_cdhdr_document.

END-OF-SELECTION.
**& ----> Step 4 : Show du protocole
  PERFORM f_disp_res.

--------------------------------------------------------------------------------------
*&---------------------------------------------------------------------*
*&  Include           ZMM_PRODUCT_CAT_DATA
*&---------------------------------------------------------------------*

TABLES: mara, makt, marc, eina, lfa1, mbew, t001, t001k, mard.

DATA: it_catalog  TYPE STANDARD TABLE OF ZMM_STR_PRODUCT_CAT,
      wa_catalog  TYPE ZMM_STR_PRODUCT_CAT,
      it_mara     TYPE STANDARD TABLE OF mara,
      it_makt     TYPE STANDARD TABLE OF makt,
      it_marc     TYPE STANDARD TABLE OF marc,
      it_mard     TYPE STANDARD TABLE OF mard,
      it_mbew     TYPE STANDARD TABLE OF mbew,
      it_eina     TYPE STANDARD TABLE OF eina,
      it_eine     TYPE STANDARD TABLE OF eine,
      it_lfa1     TYPE STANDARD TABLE OF lfa1,
      it_t001k    TYPE STANDARD TABLE OF t001k,
      it_t001     TYPE STANDARD TABLE OF t001,

      xml_string  TYPE xstring,
      status      TYPE i,
      message     TYPE string,
      http_client TYPE REF TO if_http_client,
      conv        TYPE REF TO cl_abap_conv_out_ce.

DATA: lv_subject      TYPE string.

FIELD-SYMBOLS: <e> LIKE LINE OF it_eina.
FIELD-SYMBOLS: <mara> LIKE LINE OF it_mara.
FIELD-SYMBOLS: <mard> LIKE LINE OF it_mard.
FIELD-SYMBOLS: <makt> LIKE LINE OF it_makt.
FIELD-SYMBOLS: <marc> LIKE LINE OF it_marc.
FIELD-SYMBOLS: <mbew> LIKE LINE OF it_mbew.
FIELD-SYMBOLS: <t001k> LIKE LINE OF it_t001k.
FIELD-SYMBOLS: <t001> LIKE LINE OF it_t001.
FIELD-SYMBOLS: <eina> LIKE LINE OF it_eina.
FIELD-SYMBOLS: <lfa1> LIKE LINE OF it_lfa1.

DATA: lv_xml     TYPE string,
      file_path        TYPE epsfilnam VALUE '.\zcatalog_export.xml', " Path AL11
      result_save_file TYPE string.

DATA: dest TYPE rfcdest VALUE 'FLOWIE_HTTPS_TEST'.  " Destination name in SM59

DATA: it_preview TYPE TABLE OF ZMM_STR_PRODUCT_CAT.
DATA lv_count TYPE i VALUE 0.
DATA: lv_count_01   TYPE i.
DATA: lv_stt TYPE i,
      lv_resp TYPE string,
      gv_dir  TYPE string VALUE '.\',
      lv_timestamp1 TYPE string,
      lv_timestamp TYPE string,
      gv_filename1  TYPE string,
      gv_filename  TYPE string.
DATA: lv_date TYPE char10,
      lv_time1 TYPE char8,
      lv_time TYPE char8.
DATA: lv_stat_mail TYPE boolean,
      lv_mess TYPE string.
DATA: lv_batch_size TYPE i VALUE 3000,
       lv_file_path    TYPE string.

DATA:
 gv_last_matnr  type matnr.

----------------------------------------------------------------------------------------

*&---------------------------------------------------------------------*
*&  Include           ZMM_PRODUCT_CAT_SCR
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&  Selection screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_werks TYPE marc-werks.
SELECT-OPTIONS: s_matnr FOR mara-matnr.
SELECTION-SCREEN END OF BLOCK b1.

----------------------------------------------------------------------------------------

*&---------------------------------------------------------------------*
*&  Include           ZMM_PRODUCT_CAT_PGR
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Form  F_GET_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM f_get_data .

*&---------------------------------------------------------------------*
*&  Chargement de données
*&---------------------------------------------------------------------*

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
    lv_last_changenr  TYPE cdchangenr.

  DATA:
   lt_cdhdr_cat  TYPE TABLE OF lty_cdhdr_cat,
   ls_cdhdr_cat  TYPE lty_cdhdr_cat.


**& ----> Last changed documents extracting
**& ---------
  CALL FUNCTION 'ZFLOWIE_GET_LAST_NEW_DOCUMENT'
    EXPORTING
      iv_objectclas = 'MATERIAL'
    IMPORTING
      ev_changenr   = lv_last_changenr
    TABLES
      it_cdhdr      = lt_cdhdr.

**& ----------
**& ---> Go to translation *
**& ----------
  LOOP AT lt_cdhdr INTO ls_cdhdr.
    ls_cdhdr_cat-matnr = ls_cdhdr-objectid.
    APPEND ls_cdhdr_cat TO lt_cdhdr_cat.
  ENDLOOP.


  IF NOT lt_cdhdr_cat[] IS INITIAL.
    SELECT * INTO TABLE it_mara
      FROM mara
        FOR ALL ENTRIES IN lt_cdhdr_cat
      WHERE
         mara~matnr = lt_cdhdr_cat-matnr AND
         mara~matnr IN s_matnr.    " Prendre les données dans la table MARA

  ELSEIF  lv_last_changenr IS INITIAL.
    SELECT * INTO TABLE it_mara
     FROM mara
     WHERE
        mara~matnr IN s_matnr.    " Prendre les données dans la table MARA
  ENDIF.

  SORT it_mara BY matnr.

  IF it_mara IS NOT INITIAL.
    SELECT * FROM makt INTO TABLE it_makt FOR ALL ENTRIES IN it_mara    " Prendre les données correspondates dans la table MAKT
      WHERE matnr = it_mara-matnr AND spras = sy-langu.

    SELECT * FROM marc INTO TABLE it_marc FOR ALL ENTRIES IN it_mara    " Prendre les données correspondates dans la table MARC
      WHERE matnr = it_mara-matnr AND werks = p_werks.

    IF it_marc IS NOT INITIAL.
      SELECT * FROM mard INTO TABLE it_mard FOR ALL ENTRIES IN it_marc   " Prendre les données correspondates dans la table MARD
        WHERE matnr = it_marc-matnr AND werks = it_marc-werks.

      SELECT * FROM mbew INTO TABLE it_mbew FOR ALL ENTRIES IN it_marc    " Prendre les données correspondates dans la table MBEW
        WHERE matnr = it_marc-matnr AND bwkey = it_marc-werks.  " BWKEY = WERKS
    ENDIF.

    SELECT * FROM eina INTO TABLE it_eina FOR ALL ENTRIES IN it_mara    " Prendre les données correspondates dans la table EINA
      WHERE matnr = it_mara-matnr.

    IF it_eina IS NOT INITIAL.
      DATA lt_lifnr TYPE TABLE OF eina-lifnr.
      LOOP AT it_eina ASSIGNING <e>.
        INSERT <e>-lifnr INTO TABLE lt_lifnr.
      ENDLOOP.
      SORT lt_lifnr.
      DELETE ADJACENT DUPLICATES FROM lt_lifnr.

      SELECT * FROM lfa1 INTO TABLE it_lfa1 FOR ALL ENTRIES IN lt_lifnr   " Prendre les données correspondates dans la table LFA1
        WHERE lifnr = lt_lifnr-table_line.
    ENDIF.

    IF it_mbew IS NOT INITIAL.
      SELECT * FROM t001k INTO TABLE it_t001k   " table entre MBEW et T001
        FOR ALL ENTRIES IN it_mbew
        WHERE bwkey = it_mbew-bwkey.
    ENDIF.

    IF it_t001k IS NOT INITIAL.
      SELECT * FROM t001 INTO TABLE it_t001     " Prendre les données correspondates dans la table T001
        FOR ALL ENTRIES IN it_t001k
        WHERE bukrs = it_t001k-bukrs.
    ENDIF.

  ENDIF.

ENDFORM.                    " F_GET_DATA
*&---------------------------------------------------------------------*
*&      Form  FILL_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM fill_data .

  DATA:

   ls_mara TYPE mara.

  SORT it_makt BY matnr spras.
  SORT it_marc BY matnr werks.
  SORT it_mbew BY matnr bwkey bwtar.
  SORT it_eina BY infnr.
  SORT it_t001k BY bwkey.
  SORT it_lfa1 BY lifnr.
  SORT it_t001 BY bukrs.
*&---------------------------------------------------------------------*
*&  Remplir les données dans la table interne de catalogue de produit
*&---------------------------------------------------------------------*
  LOOP AT it_mara ASSIGNING <mara>.
    CLEAR wa_catalog.

    MOVE-CORRESPONDING <mara> TO wa_catalog.

    READ TABLE it_makt ASSIGNING <makt> WITH KEY matnr = <mara>-matnr BINARY SEARCH.
    IF sy-subrc = 0. wa_catalog-maktx = <makt>-maktx. ENDIF.

    READ TABLE it_marc ASSIGNING <marc> WITH KEY matnr = <mara>-matnr werks = p_werks BINARY SEARCH.
    IF sy-subrc = 0.
      MOVE-CORRESPONDING <marc> TO wa_catalog.
    ENDIF.

    " Sum stocks MARD
    DATA: labst_sum TYPE mard-labst,
          umlme_sum TYPE mard-umlme,
          speme_sum TYPE mard-speme.
    LOOP AT it_mard ASSIGNING <mard> WHERE matnr = <mara>-matnr AND werks = p_werks.
      ADD <mard>-labst TO labst_sum.
      ADD <mard>-umlme TO umlme_sum.
      ADD <mard>-speme TO speme_sum.
      IF wa_catalog-lgort IS INITIAL. wa_catalog-lgort = <mard>-lgort. ENDIF.  " First LGORT
    ENDLOOP.
    wa_catalog-labst = labst_sum.
    wa_catalog-umlme = umlme_sum.
    wa_catalog-speme = speme_sum.

    READ TABLE it_mbew ASSIGNING <mbew> WITH KEY matnr = <mara>-matnr bwkey = p_werks BINARY SEARCH.
    IF sy-subrc = 0.
      MOVE-CORRESPONDING <mbew> TO wa_catalog.

      READ TABLE it_t001k ASSIGNING <t001k> WITH KEY bwkey = <mbew>-bwkey BINARY SEARCH.
      IF sy-subrc = 0.
        READ TABLE it_t001 ASSIGNING <t001> WITH KEY bukrs = <t001k>-bukrs BINARY SEARCH.
        IF sy-subrc = 0.
          wa_catalog-waers = <t001>-waers.
        ENDIF.
      ENDIF.
    ENDIF.

    " Supplier (first)
    READ TABLE it_eina ASSIGNING <eina> WITH KEY matnr = <mara>-matnr BINARY SEARCH.
    IF sy-subrc = 0.
      wa_catalog-lifnr = <eina>-lifnr.
      wa_catalog-infnr = <eina>-infnr.

      READ TABLE it_lfa1 ASSIGNING <lfa1> WITH KEY lifnr = <eina>-lifnr BINARY SEARCH.
      IF sy-subrc = 0.
        wa_catalog-name1 = <lfa1>-name1.
      ENDIF.
    ENDIF.

    APPEND wa_catalog TO it_catalog.
  ENDLOOP.

**& ----> Recherche du dernier element extrait
  SORT it_mara BY matnr DESCENDING.
  READ TABLE it_mara INDEX 1 INTO ls_mara.
  gv_last_matnr = ls_mara-matnr.

  SORT it_mara BY matnr.

ENDFORM.                    " FILL_DATA
*&---------------------------------------------------------------------*
*&      Form  F_DISP_RES
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM f_disp_res .

*&---------------------------------------------------------------------*
*&  Resultat
*&---------------------------------------------------------------------*


  WRITE: / 'Récupération des données : ' COLOR COL_HEADING INTENSIFIED.
  IF it_catalog IS NOT INITIAL.
    WRITE 'OK'.
  ELSE.
    WRITE 'NO'.
  ENDIF.

  WRITE: / 'Génération du XML : ' COLOR COL_HEADING INTENSIFIED.
  IF xml_string IS NOT INITIAL.
    WRITE 'OK'.
  ELSE.
    WRITE 'NO'.
  ENDIF.

  DESCRIBE TABLE it_catalog LINES lv_count.

  " Variante plus jolie :
  WRITE: / 'Nombre de produit récupéré :' COLOR COL_HEADING INTENSIFIED,
         lv_count COLOR COL_TOTAL INTENSIFIED OFF.

  WRITE: / 'Enregistrement AL11 : ' COLOR COL_HEADING INTENSIFIED.
  IF result_save_file  IS INITIAL.
    WRITE: 'Fichier XML stocké dans ', lv_file_path.
  ELSE.
    WRITE result_save_file.
  ENDIF.

  WRITE: / 'Statut Envoie mail :'.
  WRITE: / lv_mess.



ENDFORM.                    " F_DISP_RES

*&---------------------------------------------------------------------*
*&      Form  build_tag
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_TAG      text
*      -->P_VALUE    text
*      -->P_XML      text
*----------------------------------------------------------------------*
FORM build_tag USING    p_tag   TYPE string
                      p_value TYPE any
             CHANGING p_xml   TYPE string.

  DATA: lv_value TYPE string,
        lv_line  TYPE string.

  lv_value = p_value.

  " Protection caractères XML
  REPLACE ALL OCCURRENCES OF '&' IN lv_value WITH '&amp;'.
  REPLACE ALL OCCURRENCES OF '<' IN lv_value WITH '&lt;'.
  REPLACE ALL OCCURRENCES OF '>' IN lv_value WITH '&gt;'.

  CONCATENATE '    <' p_tag '>'
              lv_value
              '</' p_tag '>'
              cl_abap_char_utilities=>newline
         INTO lv_line.

  CONCATENATE p_xml lv_line INTO p_xml.

ENDFORM.                    "build_tag
*&---------------------------------------------------------------------*
*&      Form  F_XML_BATCH
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LV_BATCH_SIZE  text
*----------------------------------------------------------------------*
FORM f_xml_batch  USING    p_lv_batch_size TYPE i.

  DATA:
      lv_xml          TYPE string,
      lv_filename     TYPE string,
      lv_batch_number TYPE i VALUE 0,
      lt_po_batch     LIKE it_catalog,
      lv_tabix        TYPE sy-tabix.

**& ------> No XML parser is no data
  CHECK it_catalog[] IS NOT INITIAL.

  REFRESH lt_po_batch.
  lv_batch_number = 1.

  SELECT SINGLE low FROM tvarvc
   INTO lv_subject
      WHERE name = 'MAIL_SBJT_CAT_P' AND type = 'P' .

  LOOP AT it_catalog INTO wa_catalog.
    lv_tabix = sy-tabix.
    APPEND wa_catalog TO lt_po_batch.

    DATA lv_lines TYPE i.
    DESCRIBE TABLE lt_po_batch LINES lv_lines.
    DESCRIBE TABLE it_catalog    LINES sy-tfill.   " ou garde lines() si toléré

    IF lv_lines = p_lv_batch_size
    OR lv_tabix = sy-tfill.

      PERFORM generate_xml_one_batch
        USING    lt_po_batch     " ← nom inchangé ici
                 lv_batch_number
        CHANGING lv_file_path.

      REFRESH lt_po_batch.
      ADD 1 TO lv_batch_number.
    ENDIF.

  ENDLOOP.

ENDFORM.                    " F_XML_BATCH
*&---------------------------------------------------------------------*
*&      Form  GENERATE_XML_ONE_BATCH
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LT_PO_BATCH  text
*      -->P_LV_BATCH_NUMBER  text
*      <--P_LV_FILE_PATH  text
*----------------------------------------------------------------------*
FORM generate_xml_one_batch  USING    pt_po_batch LIKE it_catalog
                                      pv_batch_number TYPE i
                             CHANGING pv_file_path TYPE string.

  DATA:
       lv_xml         TYPE string,
       lv_date        TYPE char10,
       lv_time        TYPE char8,
       lv_time_clean  TYPE char8,
       lv_timestamp   TYPE char30,
       lv_filename    TYPE string,
       lv_msg         TYPE string.

  DATA: lv_date_xml1  TYPE char10,
        lv_date_xml2  TYPE char10.

  CLEAR lv_xml.

  CONCATENATE
    '<?xml version="1.0" encoding="UTF-8"?>'
    cl_abap_char_utilities=>newline
    '<Catalog>'
    cl_abap_char_utilities=>newline
  INTO lv_xml.

  LOOP AT pt_po_batch INTO wa_catalog.

    " Start of principal thread
    CONCATENATE lv_xml
                '  <ProduitItem>'
                cl_abap_char_utilities=>newline
           INTO lv_xml.

    " --- Formatage des dates  ---
    WRITE wa_catalog-ersda TO lv_date_xml1 DD/MM/YYYY.
    WRITE wa_catalog-laeda TO lv_date_xml2 DD/MM/YYYY.

    PERFORM build_tag USING 'MATNR' wa_catalog-matnr CHANGING lv_xml.
    PERFORM build_tag USING 'MAKTX' wa_catalog-maktx CHANGING lv_xml.
    PERFORM build_tag USING 'MTART' wa_catalog-mtart CHANGING lv_xml.
    PERFORM build_tag USING 'MATKL' wa_catalog-matkl CHANGING lv_xml.
    PERFORM build_tag USING 'BISMT' wa_catalog-bismt CHANGING lv_xml.
    PERFORM build_tag USING 'MEINS' wa_catalog-meins CHANGING lv_xml.
    PERFORM build_tag USING 'BSTME' wa_catalog-bstme CHANGING lv_xml.
    PERFORM build_tag USING 'BSTMI' wa_catalog-bstmi CHANGING lv_xml.
    PERFORM build_tag USING 'ERSDA' lv_date_xml1     CHANGING lv_xml.
    PERFORM build_tag USING 'LAEDA' lv_date_xml2     CHANGING lv_xml.
    PERFORM build_tag USING 'LIFNR' wa_catalog-lifnr CHANGING lv_xml.
    PERFORM build_tag USING 'NAME1' wa_catalog-name1 CHANGING lv_xml.
    PERFORM build_tag USING 'VERPR' wa_catalog-verpr CHANGING lv_xml.
    PERFORM build_tag USING 'INFNR' wa_catalog-infnr CHANGING lv_xml.
    PERFORM build_tag USING 'STPRS' wa_catalog-stprs CHANGING lv_xml.
    PERFORM build_tag USING 'WAERS' wa_catalog-waers CHANGING lv_xml.
    PERFORM build_tag USING 'PEINH' wa_catalog-peinh CHANGING lv_xml.
    PERFORM build_tag USING 'BKLAS' wa_catalog-bklas CHANGING lv_xml.
    PERFORM build_tag USING 'EKGRP' wa_catalog-ekgrp CHANGING lv_xml.
    PERFORM build_tag USING 'PLIFZ' wa_catalog-plifz CHANGING lv_xml.
    PERFORM build_tag USING 'WERKS' wa_catalog-werks CHANGING lv_xml.
    PERFORM build_tag USING 'LGORT' wa_catalog-lgort CHANGING lv_xml.
    PERFORM build_tag USING 'LBKUM' wa_catalog-lbkum CHANGING lv_xml.
    PERFORM build_tag USING 'LABST' wa_catalog-labst CHANGING lv_xml.
    PERFORM build_tag USING 'UMLME' wa_catalog-umlme CHANGING lv_xml.
    PERFORM build_tag USING 'SPEME' wa_catalog-speme CHANGING lv_xml.

    " End of principal thread
    CONCATENATE lv_xml
                '  </ProduitItem>'
                cl_abap_char_utilities=>newline
           INTO lv_xml.

  ENDLOOP.
  CONCATENATE lv_xml '</Catalog>' INTO lv_xml.

  " ── Nom de fichier ────────────────────────────────────────────
  WRITE sy-datum TO lv_date DD/MM/YYYY.           " → 17.03.2026
  WRITE sy-uzeit TO lv_time USING EDIT MASK '__:__:__'.   " → 09:24:00
  lv_time_clean = lv_time.
  lv_time1 = lv_time.
  REPLACE ALL OCCURRENCES OF ':' IN lv_time_clean WITH '-'.   " → 09-24-00

  CONCATENATE lv_date lv_time_clean
         INTO lv_timestamp SEPARATED BY '_'.
  CONCATENATE lv_date lv_time1
        INTO lv_timestamp1 SEPARATED BY '_'.

  " Conversion du numéro de batch en texte
  DATA lv_batch_text TYPE char10.
  WRITE pv_batch_number TO lv_batch_text LEFT-JUSTIFIED NO-ZERO.
  CONDENSE lv_batch_text NO-GAPS.

  CONCATENATE 'Cat_Produits_' lv_timestamp
              '_part' lv_batch_text
              '.xml'
         INTO lv_filename .

  CONCATENATE 'Cat_Produits_' lv_timestamp1
             '_part' lv_batch_text
             '.xml'
        INTO gv_filename1 .

  CONCATENATE gv_dir lv_filename INTO pv_file_path RESPECTING BLANKS.

  " ── Sauvegarde sur AL11 ───────────────────────────────────────
  OPEN DATASET pv_file_path
    FOR OUTPUT
    IN TEXT MODE
    ENCODING DEFAULT
    MESSAGE lv_msg.

  IF sy-subrc = 0.
    TRANSFER lv_xml TO pv_file_path.
    CLOSE DATASET pv_file_path.
    WRITE: / 'Fichier généré :', pv_file_path COLOR COL_POSITIVE.
  ELSE.
    WRITE: / 'Erreur fichier :', pv_file_path, lv_msg COLOR COL_NEGATIVE.
  ENDIF.

  " ── Transformer xml en xstring ───────────────────────────────────────
  CLEAR xml_string.
  PERFORM f_xstring USING lv_xml CHANGING xml_string.

  " ── Envoyer mail ───────────────────────────────────────
  CLEAR: lv_stat_mail, lv_mess.

  CALL FUNCTION 'Z_SEND_MAIL_XML'
    EXPORTING
      iv_recipient          = 'global@arhm.sap.stg.channel-flowie.com'
      iv_xml                = xml_string
*       IV_SENDER             =
     iv_subject_base       = lv_subject
*       IV_BODY               =
     iv_filename           = gv_filename1
      iv_interface          = 'Catalogue de produits'
    IMPORTING
     ev_success            = lv_stat_mail
     ev_message            = lv_mess
    EXCEPTIONS
     error                 = 1
     OTHERS                = 2
            .
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.

ENDFORM.                    " GENERATE_XML_ONE_BATCH
*&---------------------------------------------------------------------*
*&      Form  F_XSTRING
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LV_XML  text
*      <--P_XML_STRING  text
*----------------------------------------------------------------------*
FORM f_xstring  USING    p_lv_xml TYPE string
                CHANGING p_xml_string TYPE xstring.

*&---------------------------------------------------------------------*
*&  Convert XML File to Binary File
*&---------------------------------------------------------------------*
  CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
    EXPORTING
      text   = p_lv_xml
    IMPORTING
      buffer = p_xml_string
    EXCEPTIONS
      failed = 1
      OTHERS = 2.

  IF sy-subrc <> 0.
    WRITE: / 'Erreur conversion en XSTRING'.
    EXIT.
  ENDIF.

ENDFORM.                    " F_XSTRING
*&---------------------------------------------------------------------*
*&      Form  F_SET_LAST_CDHDR_DOCUMENT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
FORM f_set_last_cdhdr_document .

  DATA:
   lv_cdobjectv    TYPE cdobjectv.

**& ------> No XML parser is not data
  CHECK it_catalog[] IS NOT INITIAL.

**& ------> Mise à jour du dernier numéro CDHDR extrait
  lv_cdobjectv = gv_last_matnr.
  CALL FUNCTION 'ZFLOWIE_SET_LAST_DOC_NUMBER'
    EXPORTING
      iv_objectclas    = 'MATERIAL'     "/*class object
      iv_last_objectid = lv_cdobjectv.  "/*last PO found

ENDFORM.                    " F_SET_LAST_CDHDR_DOCUMENT

-----------------------------------------------------------------------------


