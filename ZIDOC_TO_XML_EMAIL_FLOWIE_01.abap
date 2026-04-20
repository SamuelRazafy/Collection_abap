ZIDOC_TO_XML_EMAIL_FLOWIE_01

FUNCTION zidoc_to_xml_email_flowie_01.
*"----------------------------------------------------------------------
*"*"Interface locale :
*"  IMPORTING
*"     VALUE(IV_EMAIL_TO) TYPE  AD_SMTPADR
*"     VALUE(IT_DOCNUMS) TYPE  ZSD_TT_DOCNUM
*"  EXPORTING
*"     REFERENCE(EV_RETURN) TYPE  BAPIRET2
*"----------------------------------------------------------------------

**& ----------------------------
**& DATE   : 09.04.2026
**& Author : SAPERP Solutions
**& Object : This function sends the IDoc status email
**& ----------------------------


  TYPES: BEGIN OF ty_idoc_data,
           docnum  TYPE edidc-docnum,
           mestyp  TYPE edidc-mestyp,
           credat  TYPE edidc-credat,
           cretim  TYPE edidc-cretim,
           status  TYPE edids-status,
           message TYPE string,
         END OF ty_idoc_data.

  DATA: lt_idoc_data    TYPE TABLE OF ty_idoc_data,
        ls_idoc_data    TYPE ty_idoc_data,
        ls_docnum       TYPE zsd_str_docnum,
        lv_status       TYPE edids-status,
        lv_xml          TYPE string,
        lv_xstring      TYPE xstring,
        lt_binary       TYPE solix_tab,
        lv_size         TYPE so_obj_len,
        lo_send_request TYPE REF TO cl_bcs,
        lo_document     TYPE REF TO cl_document_bcs,
        lo_sender       TYPE REF TO if_sender_bcs,
        lo_recipient    TYPE REF TO if_recipient_bcs,
        lt_text         TYPE bcsy_text.

  DATA: lv_date_fr TYPE c LENGTH 10,
      lv_time_fr TYPE c LENGTH 8,
      lv_timestamp_str TYPE string.

  DATA: lv_stamid TYPE edids-stamid,
        lv_stamno TYPE edids-stamno,
        lv_stapa1 TYPE edids-stapa1,
        lv_stapa2 TYPE edids-stapa2,
        lv_stapa3 TYPE edids-stapa3,
        lv_stapa4 TYPE edids-stapa4.

  DATA: lv_countr TYPE edids-countr.
  DATA: lv_cr_lf TYPE c LENGTH 2.
  DATA: lv_time_formatted TYPE string.
  DATA: lv_safe_msg TYPE string.
  DATA: lv_date_iso TYPE string.
  DATA: lv_line TYPE string,
      lv_crlf TYPE c LENGTH 2.
  DATA: ls_line LIKE LINE OF lt_text.
  DATA: lv_subject TYPE so_obj_des.
  DATA: lx_bcs TYPE REF TO cx_bcs,
      lv_msg TYPE string.



  CLEAR ev_return.

  "====================================================================
  " 1. Vérification des données d'entrée
  "====================================================================
  IF it_docnums IS INITIAL.
    ev_return-type = 'E'.
    ev_return-message = 'Aucune donnée fournie dans IT_DOCNUMS.'.
    MESSAGE ev_return-message TYPE 'E'.
    RETURN.
  ENDIF.

  "====================================================================
  " 2. Récupération des informations des IDOCs
  "====================================================================
  LOOP AT it_docnums INTO ls_docnum.
    CLEAR: ls_idoc_data, lv_status.

    ls_idoc_data-docnum = ls_docnum-docnum.

    " Récupération MESTYP et CREDAT et CRETIM
    SELECT SINGLE mestyp credat cretim
      INTO CORRESPONDING FIELDS OF ls_idoc_data
      FROM edidc
      WHERE docnum = ls_docnum-docnum.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.


    " Récupération du dernier statut et des variables de message
    SELECT status stamid stamno stapa1 stapa2 stapa3 stapa4 countr
     FROM edids
     INTO (ls_idoc_data-status, lv_stamid, lv_stamno,
           lv_stapa1, lv_stapa2, lv_stapa3, lv_stapa4, lv_countr)
     UP TO 1 ROWS
     WHERE docnum = ls_docnum-docnum
     ORDER BY countr DESCENDING.
    ENDSELECT.

    IF sy-subrc = 0.
      " Reconstitution du texte du message
      MESSAGE ID lv_stamid TYPE 'S' NUMBER lv_stamno
        WITH lv_stapa1 lv_stapa2 lv_stapa3 lv_stapa4
        INTO ls_idoc_data-message.
    ENDIF.

    APPEND ls_idoc_data TO lt_idoc_data.
  ENDLOOP.

  IF lt_idoc_data IS INITIAL.
    ev_return-type = 'I'.
    ev_return-message = 'Aucun IDOC valide trouvé pour les numéros fournis.'.
    MESSAGE ev_return-message TYPE 'I'.
    RETURN.
  ENDIF.

  "====================================================================
  " 3. Génération du fichier XML
  "====================================================================
  lv_cr_lf = cl_abap_char_utilities=>cr_lf.
  CONCATENATE '<?xml version="1.0" encoding="UTF-8"?>'
            lv_cr_lf
            '<idocs>'
            lv_cr_lf
       INTO lv_xml.

  LOOP AT lt_idoc_data INTO ls_idoc_data.
    CONCATENATE ls_idoc_data-cretim(2) ':'
            ls_idoc_data-cretim+2(2) ':'
            ls_idoc_data-cretim+4(2)
       INTO lv_time_formatted.
    lv_safe_msg = cl_http_utility=>escape_html( ls_idoc_data-message ).
    CONCATENATE ls_idoc_data-credat(4)  '-'
            ls_idoc_data-credat+4(2) '-'
            ls_idoc_data-credat+6(2)
       INTO lv_date_iso.
    CONCATENATE lv_xml
                '  <idoc>'                              lv_crlf
                '    <docnum>' ls_idoc_data-docnum '</docnum>' lv_crlf
                '    <mestyp>' ls_idoc_data-mestyp '</mestyp>' lv_crlf
                '    <credat>' lv_date_iso         '</credat>' lv_crlf
                '    <cretim>' lv_time_formatted   '</cretim>' lv_crlf
                '    <status>' ls_idoc_data-status '</status>' lv_crlf
                '    <message>' lv_safe_msg        '</message>' lv_crlf
                '  </idoc>'                             lv_crlf
           INTO lv_xml.
  ENDLOOP.

  CONCATENATE lv_xml '</idocs>' INTO lv_xml.


  " Conversion String → XSTRING
  CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
    EXPORTING
      text   = lv_xml
    IMPORTING
      buffer = lv_xstring
    EXCEPTIONS
      failed = 1
      OTHERS = 2.

  IF sy-subrc <> 0.
    WRITE: / 'Erreur conversion en XSTRING'.
    EXIT.
  ENDIF.


  " Conversion String → XSTRING
  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING      "text = lv_xml
      buffer     = lv_xstring
    TABLES
      binary_tab = lt_binary
    EXCEPTIONS
      OTHERS     = 1.

  lv_size = XSTRLEN( lv_xstring ).

  IF sy-subrc <> 0.
    ev_return-type = 'E'.
    ev_return-message = 'Erreur lors de la conversion du XML.'.
    MESSAGE ev_return-message TYPE 'E'.
    RETURN.
  ENDIF.

  "====================================================================
  " 4. Envoi par email
  "====================================================================
  TRY.
      lo_send_request = cl_bcs=>create_persistent( ).

      CLEAR lt_text.

      ls_line-line = 'Bonjour,'.
      APPEND ls_line TO lt_text.

      ls_line-line = ''.
      APPEND ls_line TO lt_text.

      ls_line-line = 'Veuillez trouver en pièce jointe le fichier XML contenant :'.
      APPEND ls_line TO lt_text.

      ls_line-line = ''.
      APPEND ls_line TO lt_text.

      " On vide la structure de ligne
      CLEAR ls_line.

                                                            " Ligne 1
      ls_line-line = '- Numéro Idoc (DOCNUM)'.
      APPEND ls_line TO lt_text.

                                                            " Ligne 2
      ls_line-line = '- Type de message (MESTYP)'.
      APPEND ls_line TO lt_text.

                                                            " Ligne 3
      ls_line-line = '- Date de création (CREDAT)'.
      APPEND ls_line TO lt_text.

                                                            " Ligne 4
      ls_line-line = '- Heure de création (CRETIM)'.
      APPEND ls_line TO lt_text.

                                                            " Ligne 5
      ls_line-line = '- Statut Idoc (STATUS)'.
      APPEND ls_line TO lt_text.

                                                            " Ligne 6
      ls_line-line = '- Message (MESSAGE)'.
      APPEND ls_line TO lt_text.

      ls_line-line = ''.
      APPEND ls_line TO lt_text.

      ls_line-line = 'Cordialement,'.
      APPEND ls_line TO lt_text.
      ls_line-line = ''.
      APPEND ls_line TO lt_text.

      ls_line-line = 'Interface SAP'.
      APPEND ls_line TO lt_text.

      "====================================================================
      " Préparation de la date et l'heure d'envoi
      "====================================================================
      " Formatage Date : AAAA/MM/JJ -> JJ.MM.AAAA (ou autre format selon préférence)
      WRITE sy-datum TO lv_date_fr.
      " Formatage Heure : HHMMSS -> HH:MM:SS
      WRITE sy-uzeit TO lv_time_fr.

      " Création de la chaîne d'horodatage
      CONCATENATE lv_date_fr 'à' lv_time_fr INTO lv_timestamp_str SEPARATED BY space.

      SELECT SINGLE LOW FROM TVARVC
            INTO lv_subject
               WHERE NAME = 'ZSBJT_MAIL_01' AND type = 'P' .

      " Ajout de la date et l'heure à la fin du sujet
      CONCATENATE lv_subject 'DU'  lv_timestamp_str
             INTO lv_subject
             SEPARATED BY space.

      " Utilisation du sujet dans le document
      lo_document = cl_document_bcs=>create_document(
                       i_type    = 'RAW'
                       i_text    = lt_text
                       i_subject = lv_subject ).



      " Pièce jointe XML
      lo_document->add_attachment(
        i_attachment_type    = 'XML'
        i_attachment_subject = 'idocs_export.xml'
        i_attachment_size    = lv_size
        i_att_content_hex    =  lt_binary  ).

      " Expéditeur (utilisateur courant)
      lo_sender = cl_sapuser_bcs=>create( sy-uname ).
      lo_send_request->set_sender( lo_sender ).

      " Destinataire
      lo_recipient = cl_cam_address_bcs=>create_internet_address( iv_email_to ).
      lo_send_request->add_recipient( i_recipient = lo_recipient
                                      i_express   = abap_true ).

      lo_send_request->set_document( lo_document ).

      lo_send_request->send( EXPORTING i_with_error_screen = abap_false ).
      COMMIT WORK AND WAIT.

      ev_return-type = 'S'.
      CONCATENATE 'Email envoyé avec succès à '
            iv_email_to
            ' avec le fichier XML.'
       INTO ev_return-message.

      MESSAGE ev_return-message TYPE 'S'.

    CATCH cx_bcs INTO lx_bcs.
      ev_return-type = 'E'.

      " Récupération du texte de l'exception
      lv_msg = lx_bcs->get_text( ).

      " Assemblage du message (Pas de |...| en 7.01)
      CONCATENATE 'Erreur d''envoi email :' lv_msg
             INTO ev_return-message
             SEPARATED BY space.

      MESSAGE ev_return-message TYPE 'E'.
  ENDTRY.

ENDFUNCTION.

----------------------------------------------------------------------------

Structure : ZSD_STR_DOCNUM

MANDT	MANDT	CLNT	3	0	Mandant
DOCNUM	EDI_DOCNUM	NUMC	16	0	Numéro de l'IDoc

