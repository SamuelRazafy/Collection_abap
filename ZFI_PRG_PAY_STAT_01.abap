Programme : ZFI_PRG_PAY_STAT_01

*&---------------------------------------------------------------------*
*& Report ZFI_PRG_PAY_STAT_01                                          *
*&---------------------------------------------------------------------*
*               *** Statut de paiement ***                             *
*                                                                      *
* SAP Name            :  ZFI_PRG_PAY_STAT_01                           *
*                                                                      *
* Package             :  ZFI_001                                       *
*                                                                      *
* Title               :  Programme Pour Le Statut de paiement          *
*                                                                      *
* Module              :  FI                                            *
*                                                                      *
* Author              :  SAPERP SOLUTION                               *
*                                                                      *
* Creation date       :  24.02.2026                                    *
*                                                                      *
* Transaction code    :  xxx                                           *
*                                                                      *
*----------------------------------------------------------------------*
*                 *** Modifications history ***                        *
*                                                                      *
* Date        User ID               Transport / Description            *
* ==========  ====================  ================================== *
* 24.02.2026  FLOWIETECH            DEVK904284       Creation          *
* 24.03.2026  FLOWIETECH            DEVK904284       Modification xml  *
*----------------------------------------------------------------------*

REPORT  ZFI_PRG_PAY_STAT_01.

INCLUDE ZFI_PRG_PAY_STAT_01_top.
INCLUDE ZFI_PRG_PAY_STAT_01_scr.
INCLUDE ZFI_PRG_PAY_STAT_01_forms.

START-OF-SELECTION.

  PERFORM f_get_data.                                   " Chercher les données

*  PERFORM f_xml USING lv_xml.                           " Transformation XML

*  PERFORM f_xstring USING lv_xml CHANGING xml_string.   " Convert XML File to Binary File

  PERFORM f_xml_batch USING lv_batch_size.  " Génération du fichier xml, enregistrement dans AL11, Envoie par mail


end-of-SELECTION.

  PERFORM f_disp_res.

---------------------------------------------------------------------------------------------------------------

INCLUDE ZFI_PRG_PAY_STAT_01_top.


*&---------------------------------------------------------------------*
*&  Include           ZFI_PRG_PAY_STAT_01_TOP
*&---------------------------------------------------------------------*

DATA: stat_fact TYPE zfi_tt_stat_paiement.
DATA: ls_stat_fact TYPE zfi_str_stat_paiement.
DATA: lv_xml TYPE string.

DATA: file_path        TYPE epsfilnam, " Path AL11
      result_save_file TYPE string,
      xml_string       TYPE xstring.
DATA: lv_nl TYPE CHAR1.
DATA: lv_lines TYPE i.
DATA: lv_stt  TYPE i,
      lv_resp TYPE string,
      gv_dir  TYPE string VALUE '.\',
      lv_timestamp TYPE string,
      lv_timestamp1 TYPE string,
      gv_filename1  TYPE string,
      gv_filename  TYPE string.
DATA: lv_date TYPE char10,
      lv_time1 TYPE char8,
      lv_time TYPE char8.
DATA: lv_stat_mail TYPE boolean,
      lv_mess TYPE string.
DATA: lv_batch_size TYPE i VALUE 3000.

----------------------------------------------------------------------------------------------------------------

INCLUDE ZFI_PRG_PAY_STAT_01_scr.

*&---------------------------------------------------------------------*
*&  Include           ZFI_PRG_PAY_STAT_01_SCR
*&---------------------------------------------------------------------*

 SELECTION-SCREEN BEGIN OF BLOCK frame1 WITH FRAME TITLE TEXT-001.
  SELECTION-SCREEN ULINE /10(40).

  PARAMETERS: p_BUKRS  TYPE bukrs,
              p_LIFNR  TYPE lifnr,
              p_F_DATE TYPE bldat,
              p_T_DATE TYPE bldat.

  SELECTION-SCREEN ULINE /10(40).
SELECTION-SCREEN END OF BLOCK frame1.

----------------------------------------------------------------------------------------------------------------

INCLUDE ZFI_PRG_PAY_STAT_01_forms.

*&---------------------------------------------------------------------*
*&  Include           ZFI_PRG_PAY_STAT_01_FORMS
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Form  F_GET_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM F_GET_DATA .

  CALL FUNCTION 'ZFI_PAY_STAT_03'
    EXPORTING
      iv_bukrs     = p_BUKRS
      iv_lifnr     = p_LIFNR
      iv_from_date = p_F_DATE
      iv_to_date   = p_T_DATE
    IMPORTING
      et_invoices  = stat_fact.

  IF stat_fact IS INITIAL.
    WRITE: / 'Aucune données trouvées!'.
    RETURN.
  ENDIF.

ENDFORM.                    " F_GET_DATA
*&---------------------------------------------------------------------*
*&      Form  F_XML
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->LV_XML  text
*----------------------------------------------------------------------*
FORM F_XML  USING    LV_XML TYPE string.

  CLEAR lv_xml.

  lv_xml = '<?xml version="1.0" encoding="UTF-8"?>'.          " première ligne

  lv_nl = cl_abap_char_utilities=>newline.

  CONCATENATE lv_xml
              lv_nl
              '<StatutPaiementFournisseur>'
              lv_nl
         INTO lv_xml RESPECTING BLANKS.

  LOOP AT stat_fact INTO ls_stat_fact.
    CONCATENATE lv_xml '<StatutPaiement>' lv_nl INTO lv_xml RESPECTING BLANKS.

    PERFORM build_tag USING 'BUKRS'  ls_stat_fact-bukrs  CHANGING lv_xml.
    PERFORM build_tag USING 'BELNR'  ls_stat_fact-belnr  CHANGING lv_xml.
    PERFORM build_tag USING 'GJAHR'  ls_stat_fact-gjahr  CHANGING lv_xml.
    PERFORM build_tag USING 'BLART'  ls_stat_fact-blart  CHANGING lv_xml.
    PERFORM build_tag USING 'BLDAT'  ls_stat_fact-bldat  CHANGING lv_xml.
    PERFORM build_tag USING 'BUDAT'  ls_stat_fact-budat  CHANGING lv_xml.
    PERFORM build_tag USING 'LIFNR'  ls_stat_fact-lifnr  CHANGING lv_xml.
    PERFORM build_tag USING 'WAERS'  ls_stat_fact-waers  CHANGING lv_xml.
    PERFORM build_tag USING 'DMBTR'  ls_stat_fact-dmbtr  CHANGING lv_xml.
    PERFORM build_tag USING 'REMAINING_DUE'  ls_stat_fact-remaining_due  CHANGING lv_xml.
    PERFORM build_tag USING 'STATUS'  ls_stat_fact-status  CHANGING lv_xml.
    PERFORM build_tag USING 'PAYMENT_DATE'  ls_stat_fact-payment_date  CHANGING lv_xml.
    PERFORM build_tag USING 'AUGBL'  ls_stat_fact-augbl  CHANGING lv_xml.

    CONCATENATE lv_xml '</StatutPaiement>' lv_nl INTO lv_xml RESPECTING BLANKS.

  ENDLOOP.

  CONCATENATE lv_xml '</StatutPaiementFournisseur>' INTO lv_xml RESPECTING BLANKS.

  " Date → DD.MM.YYYY
  WRITE sy-datum TO lv_date DD/MM/YYYY.   " ← le / est remplacé automatiquement par .

  " Heure → hh:mm:ss
  WRITE sy-uzeit TO lv_time USING EDIT MASK '__:__:__'.
  lv_time1 = lv_time.
  REPLACE ALL OCCURRENCES OF ':' IN lv_time WITH '-'.

  " Construction timestamp
  CONCATENATE lv_date lv_time INTO lv_timestamp SEPARATED BY '_'.
  CONCATENATE lv_date lv_time1 INTO lv_timestamp1 SEPARATED BY '_'.

  " Nom fichier dynamique
  CONCATENATE 'Stat_Paiement_'lv_timestamp'.xml' INTO gv_filename RESPECTING BLANKS.
  CONCATENATE 'Stat_Paiement_'lv_timestamp1'.xml' INTO gv_filename1 RESPECTING BLANKS.

  "Chemin complet
  CONCATENATE gv_dir gv_filename INTO file_path RESPECTING BLANKS.

  " Enregitrement dans AL11
  OPEN DATASET file_path
    FOR OUTPUT
    IN TEXT MODE
    ENCODING DEFAULT
    MESSAGE result_save_file.

  IF sy-subrc = 0.

    TRANSFER lv_xml TO file_path.

    CLOSE DATASET file_path.
  ELSE.
    MESSAGE 'Erreur ouverture fichier AL11' TYPE 'E'.
    EXIT.

  ENDIF.

ENDFORM.                    " F_XML
*&---------------------------------------------------------------------*
*&      Form  F_XSTRING
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->LV_XML  text
*      <--XML_STRING  text
*----------------------------------------------------------------------*
FORM F_XSTRING  USING    LV_XML TYPE string
                CHANGING XML_STRING TYPE xstring.

  CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
    EXPORTING
      text   = lv_xml
    IMPORTING
      buffer = xml_string
    EXCEPTIONS
      failed = 1
      OTHERS = 2.

  IF sy-subrc <> 0.
    WRITE: / 'Erreur conversion en XSTRING'.
    EXIT.
  ENDIF.

ENDFORM.                    " F_XSTRING
*&---------------------------------------------------------------------*
*&      Form  F_DISP_RES
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM F_DISP_RES .

  " Afficher les résultats
  WRITE: / 'Récupération des données : '.
  IF stat_fact IS NOT INITIAL.
    WRITE: 'OK'.
  ELSE.
    WRITE: 'NO'.
  ENDIF.

  DESCRIBE TABLE stat_fact LINES lv_lines.
  WRITE: / 'Nombre de factures récupérées : ', lv_lines COLOR COL_TOTAL INTENSIFIED OFF.

  WRITE: / 'Génération du XML : '.
  IF xml_string IS NOT INITIAL.
    WRITE: 'OK'.
  ELSE.
    WRITE: 'NO'.
  ENDIF.

  WRITE: / 'Enregistrement AL11 : '.
  IF result_save_file IS NOT INITIAL.
    WRITE result_save_file.
  ELSE.
    WRITE: 'Fichier XML stocké dans : ', file_path COLOR COL_HEADING INTENSIFIED OFF.
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
FORM F_XML_BATCH  USING    P_LV_BATCH_SIZE TYPE i.

  DATA: lv_xml          TYPE string,
      lv_filename     TYPE string,
      lv_file_path    TYPE string,
      lv_batch_number TYPE i VALUE 0,
      lt_po_batch     LIKE stat_fact,
*      ls_po           LIKE LINE OF stat_fact,
      lv_tabix        TYPE sy-tabix.

  REFRESH lt_po_batch.
  lv_batch_number = 1.

  LOOP AT stat_fact INTO ls_stat_fact.
    lv_tabix = sy-tabix.
    APPEND ls_stat_fact TO lt_po_batch.

    DATA lv_lines TYPE i.
    DESCRIBE TABLE lt_po_batch LINES lv_lines.
    DESCRIBE TABLE stat_fact    LINES sy-tfill.   " ou garde lines() si toléré

    IF lv_lines = P_LV_BATCH_SIZE
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
FORM GENERATE_XML_ONE_BATCH  USING    PT_PO_BATCH like stat_fact
                                      PV_BATCH_NUMBER TYPE  i
                             CHANGING PV_FILE_PATH TYPE string.


  DATA: lv_xml         TYPE string,
        lv_date        TYPE char10,
        lv_time        TYPE char8,
        lv_time1        TYPE char8,
        lv_time_clean  TYPE char8,
        lv_timestamp   TYPE char30,
        lv_timestamp1   TYPE char30,
        lv_filename    TYPE string,
        lv_msg         TYPE string,
        ls_po          LIKE LINE OF pt_po_batch.
*        ls_item        LIKE LINE OF ls_po-items.

  CLEAR lv_xml.

  CONCATENATE
    '<?xml version="1.0" encoding="UTF-8"?>'
    cl_abap_char_utilities=>newline
    '<StatutPaiementFournisseur>'
    cl_abap_char_utilities=>newline
  INTO lv_xml.

  LOOP AT pt_po_batch INTO ls_stat_fact.

    CONCATENATE lv_xml '<StatutPaiement>' lv_nl INTO lv_xml RESPECTING BLANKS.

    PERFORM build_tag USING 'BUKRS'  ls_stat_fact-bukrs  CHANGING lv_xml.
    PERFORM build_tag USING 'BELNR'  ls_stat_fact-belnr  CHANGING lv_xml.
    PERFORM build_tag USING 'GJAHR'  ls_stat_fact-gjahr  CHANGING lv_xml.
    PERFORM build_tag USING 'BLART'  ls_stat_fact-blart  CHANGING lv_xml.
    PERFORM build_tag USING 'BLDAT'  ls_stat_fact-bldat  CHANGING lv_xml.
    PERFORM build_tag USING 'BUDAT'  ls_stat_fact-budat  CHANGING lv_xml.
    PERFORM build_tag USING 'LIFNR'  ls_stat_fact-lifnr  CHANGING lv_xml.
    PERFORM build_tag USING 'WAERS'  ls_stat_fact-waers  CHANGING lv_xml.
    PERFORM build_tag USING 'DMBTR'  ls_stat_fact-dmbtr  CHANGING lv_xml.
    PERFORM build_tag USING 'REMAINING_DUE'  ls_stat_fact-remaining_due  CHANGING lv_xml.
    PERFORM build_tag USING 'STATUS'  ls_stat_fact-status  CHANGING lv_xml.
    PERFORM build_tag USING 'PAYMENT_DATE'  ls_stat_fact-payment_date  CHANGING lv_xml.
    PERFORM build_tag USING 'AUGBL'  ls_stat_fact-augbl  CHANGING lv_xml.

    CONCATENATE lv_xml '</StatutPaiement>' lv_nl INTO lv_xml RESPECTING BLANKS.

  ENDLOOP.
  CONCATENATE lv_xml '</StatutPaiementFournisseur>' INTO lv_xml.

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

  CONCATENATE 'Stat_Paiement_' lv_timestamp
              '_part' lv_batch_text
              '.xml'
         INTO lv_filename .

  CONCATENATE 'Stat_Paiement_' lv_timestamp1
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
      IV_RECIPIENT          = 'global@arhm.sap.stg.channel-flowie.com'
      IV_XML                = xml_string
*       IV_SENDER             =
     IV_SUBJECT_BASE       = 'Statut de paiement du '
*       IV_BODY               =
     IV_FILENAME           = gv_filename1
      IV_INTERFACE          = 'Statut de paiement'
    IMPORTING
     EV_SUCCESS            = lv_stat_mail
     EV_MESSAGE            = lv_mess
    EXCEPTIONS
     ERROR                 = 1
     OTHERS                = 2
            .
  IF SY-SUBRC <> 0.
    MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
            WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.

ENDFORM.                    " GENERATE_XML_ONE_BATCH


