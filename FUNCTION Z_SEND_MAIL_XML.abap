FUNCTION Z_SEND_MAIL_XML.
*"----------------------------------------------------------------------
*"*"Interface locale :
*"  IMPORTING
*"     REFERENCE(IV_RECIPIENT) TYPE  AD_SMTPADR
*"     REFERENCE(IV_XML) TYPE  XSTRING
*"     REFERENCE(IV_SENDER) TYPE  AD_SMTPADR OPTIONAL
*"     REFERENCE(IV_SUBJECT_BASE) TYPE  STRING
*"     REFERENCE(IV_BODY) TYPE  BCSY_TEXT OPTIONAL
*"     REFERENCE(IV_FILENAME) TYPE  STRING
*"     REFERENCE(IV_INTERFACE) TYPE  STRING
*"  EXPORTING
*"     REFERENCE(EV_SUCCESS) TYPE  BOOLEAN
*"     REFERENCE(EV_MESSAGE) TYPE  STRING
*"  EXCEPTIONS
*"      ERROR
*"----------------------------------------------------------------------

  DATA: lo_send_request TYPE REF TO cl_bcs,
        lo_document     TYPE REF TO cl_document_bcs,
        lo_sender       TYPE REF TO if_sender_bcs,
        lo_recipient    TYPE REF TO if_recipient_bcs,
        lo_exception    TYPE REF TO cx_bcs,

        lt_body         TYPE bcsy_text,
        lv_subject      TYPE so_obj_des,
        lt_att_hex      TYPE solix_tab,
        lv_size         TYPE so_obj_len,
        lt_header       TYPE soli_tab,
        lv_line         TYPE soli,

        lv_date         TYPE char10,
        lv_time         TYPE char8,
        lv_full_subject TYPE string,

        lv_att_subject  TYPE so_obj_des.  " <--- Ajout pour compatibilité type
  DATA: lv_line1         TYPE string.
    DATA:
    lv_date_formatted TYPE string,
    lv_time_formatted TYPE string,
    lv_datetime       TYPE string.

  "=== 1. Construction date/heure de l'envoi (DD.MM.YYYY hh:mm:ss) ===
  CONCATENATE sy-datum+6(2) '.' sy-datum+4(2) '.' sy-datum(4)
         INTO lv_date.
  CONCATENATE sy-uzeit(2)   ':' sy-uzeit+2(2)   ':' sy-uzeit+4(2)
         INTO lv_time.

  CONCATENATE iv_subject_base lv_date lv_time
         INTO lv_full_subject SEPARATED BY space.
  lv_subject = lv_full_subject.   " max 50 caractères (so_obj_des)

  "=== 2. Corps du mail (si non fourni, texte par défaut) ===
  IF iv_body IS INITIAL.


    APPEND '[INT-SAP] Notification d''envoi de fichier'    TO lt_body.
    APPEND space TO lt_body.

    APPEND 'Bonjour,'                     TO lt_body.
    APPEND space TO lt_body.

    APPEND 'Le système SAP a généré et transmis un fichier dans le cadre d''un échange automatique.' TO lt_body.
    APPEND space TO lt_body.

    APPEND 'Détails de la transmission :' TO lt_body.
    APPEND space TO lt_body.

    CONCATENATE 'Interface :' iv_interface INTO lv_line1 SEPARATED BY space.
    APPEND lv_line1 TO lt_body.

    APPEND 'Système source : SAP ARHM' TO lt_body.

    CONCATENATE sy-datum+0(4) '-' sy-datum+4(2) '-' sy-datum+6(2) INTO lv_date_formatted.
    CONCATENATE sy-uzeit+0(2) ':' sy-uzeit+2(2) ':' sy-uzeit+4(2) INTO lv_time_formatted.
    CONCATENATE lv_date_formatted lv_time_formatted INTO lv_datetime SEPARATED BY space.
    CONCATENATE 'Date/heure d''envoi :' lv_datetime INTO lv_line1 SEPARATED BY space.
    APPEND lv_line1 TO lt_body.

    CONCATENATE 'Nom du fichier :' iv_filename INTO lv_line1 SEPARATED BY space.
    APPEND lv_line1 TO lt_body.

    APPEND space TO lt_body.
    APPEND 'Le fichier est disponible en pièce jointe.' TO lt_body.
    APPEND space TO lt_body.

    APPEND 'Ceci est un message automatique, merci de ne pas répondre.' TO lt_body.
    APPEND space TO lt_body.

    APPEND 'Cordialement,'                TO lt_body.
    APPEND 'Interface SAP' TO lt_body.


  ELSE.
    lt_body = iv_body.
  ENDIF.

  TRY.
      "=== 3. Création de la requête BCS ===
      lo_send_request = cl_bcs=>create_persistent( ).

      "=== 4. Document principal ===
      lo_document = cl_document_bcs=>create_document(
        i_type    = 'RAW'
        i_text    = lt_body
        i_subject = lv_subject
      ).

      "=== 5. Pièce jointe XML (à partir du XSTRING) ===
      lt_att_hex = cl_bcs_convert=>xstring_to_solix( iv_xml )."cl_document_bcs=>xstring_to_solix( iv_xml ).
      lv_size    = xstrlen( iv_xml ).

      " Force le nom de fichier réel (important pour .xml)
      CLEAR lv_line.
      CONCATENATE '&SO_FILENAME=' iv_filename INTO lv_line.
      APPEND lv_line TO lt_header.

      " <--- Correction : Assignation à variable compatible
      lv_att_subject = iv_filename.  " Tronque à 50 char si nécessaire

      lo_document->add_attachment(
        i_attachment_type    = 'XML'
        i_attachment_subject = lv_att_subject  " <--- Utilisation de la variable
        i_attachment_size    = lv_size
        i_att_content_hex    = lt_att_hex
        i_attachment_header  = lt_header
      ).

      "=== 6. Expéditeur (optionnel) ===
      IF iv_sender IS NOT INITIAL.
        lo_sender = cl_cam_address_bcs=>create_internet_address( iv_sender ).
        lo_send_request->set_sender( lo_sender ).
      ENDIF.

      "=== 7. Destinataire ===
      lo_recipient = cl_cam_address_bcs=>create_internet_address( iv_recipient ).
      lo_send_request->add_recipient(
        i_recipient = lo_recipient
        i_express   = abap_true
      ).

      "=== 8. Lien document + envoi ===
      lo_send_request->set_document( lo_document ).
      lo_send_request->send( ).

      COMMIT WORK AND WAIT.

      ev_success = abap_true.
      ev_message = 'Email envoyé avec succès (XML en pièce jointe)'.

    CATCH cx_bcs INTO lo_exception.
      ev_success = abap_false.
      ev_message = lo_exception->get_text( ).
      RAISE error.
  ENDTRY.




ENDFUNCTION.