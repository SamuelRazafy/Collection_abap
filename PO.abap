*&---------------------------------------------------------------------*
*&  Include           ZMM_PO_FLOWIE_FORMS
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


  " Lecture des données

*   Récuperation des données dans la table EKKO

  IF p_lifnr IS INITIAL.
    SELECT *
  FROM ekko
    INTO CORRESPONDING FIELDS OF TABLE lt_ekko
  WHERE ebeln IN s_ebeln.
  ELSE.
    SELECT *
FROM ekko
  INTO CORRESPONDING FIELDS OF TABLE lt_ekko
WHERE ebeln IN s_ebeln
  and lifnr = p_lifnr.

  ENDIF.



  IF lt_ekko IS INITIAL.
    MESSAGE 'Commande achat introuvable' TYPE 'I'.
    RETURN.
  ENDIF.

*   Récuperation des données dans la table EKPO

  SORT lt_ekko by ebeln.
  delete ADJACENT DUPLICATES FROM lt_ekko COMPARING ebeln.

  SELECT *
  FROM ekpo
    INTO CORRESPONDING FIELDS OF TABLE lt_ekpo
  FOR ALL ENTRIES IN lt_ekko
  WHERE ebeln = lt_ekko-ebeln.

*   Récuperation des données dans la table LFA1

  SELECT *
  FROM lfa1
    INTO CORRESPONDING FIELDS OF TABLE lt_lfa1
  FOR ALL ENTRIES IN lt_ekko
  WHERE lifnr = lt_ekko-lifnr.

  SORT lt_ekpo by ebeln.
  delete ADJACENT DUPLICATES FROM lt_ekpo COMPARING ebeln.

*   Récuperation des données dans la table MAKTX

  SELECT maktx
  FROM makt
    INTO CORRESPONDING FIELDS OF TABLE lt_makt
  FOR ALL ENTRIES IN lt_ekpo
  WHERE matnr = lt_ekpo-matnr
  AND spras = sy-langu.

*   Récuperation des données dans la table EKKN

  SELECT *
  FROM ekkn
    INTO TABLE lt_ekkn
  FOR ALL ENTRIES IN lt_ekpo
  WHERE ebeln = lt_ekpo-ebeln
    AND ebelp = lt_ekpo-ebelp.


*   Récuperation des données dans la table KONV

  SELECT knumv kschl kwert
   FROM konv
    INTO CORRESPONDING FIELDS OF TABLE  lt_prcd_elements
   FOR ALL ENTRIES IN lt_ekko
   WHERE knumv = lt_ekko-knumv
   .

* Récuperation des données dans la table EKBE

  SELECT ebeln        " PO Number
       ebelp        " Item Number
       vgabe        " Transaction/Event Type (1=GR, 2=Invoice)
       menge        " Quantity
       dmbtr        " Amount (Company Code Currency)
       shkzg         " Debit/Credit Indicator
  FROM ekbe
     INTO CORRESPONDING FIELDS OF TABLE lt_ekbe
   FOR ALL ENTRIES IN lt_ekpo
  WHERE ebeln = lt_ekpo-ebeln
    AND ebelp = lt_ekpo-ebelp
 .

* Remplir les données d'entête

  LOOP AT lt_ekko INTO ls_ekko.
    CLEAR gs_po.
    CLEAR gs_po-items.

*    Header
    gs_po-header-ebeln = ls_ekko-ebeln.
    gs_po-header-bukrs = ls_ekko-bukrs.
    gs_po-header-bsart = ls_ekko-bsart.
    gs_po-header-statu = ls_ekko-frgke.
    gs_po-header-aedat = ls_ekko-aedat.
    gs_po-header-bedat = ls_ekko-bedat.
    gs_po-header-lifnr = ls_ekko-lifnr.

    READ TABLE lt_lfa1 INTO ls_lfa1
             WITH KEY lifnr = ls_ekko-lifnr.
    IF sy-subrc = 0.
      gs_po-header-name1 = ls_lfa1-name1.
    ENDIF.

    gs_po-header-ekorg = ls_ekko-ekorg.
    gs_po-header-ekgrp = ls_ekko-ekgrp.
    gs_po-header-waers = ls_ekko-waers.
    gs_po-header-zterm = ls_ekko-zterm.
    gs_po-header-inco1 = ls_ekko-inco1.

    " Items
    LOOP AT lt_ekpo INTO ls_ekpo WHERE ebeln = ls_ekko-ebeln.

      CLEAR:
            ls_item-gr_qty,
            ls_item-iv_qty,
            ls_item-gr_amt,
            ls_item-iv_amt,
            ls_item-qty_remaining,
            ls_item-amt_remaining.


      ls_item-ebelp = ls_ekpo-ebelp.
      ls_item-matnr = ls_ekpo-matnr.

      READ TABLE lt_makt INTO ls_makt
                 WITH KEY matnr = ls_ekpo-matnr.
      IF sy-subrc = 0.
        ls_item-maktx = ls_makt-maktx.
      ENDIF.

      ls_item-werks = ls_ekpo-werks.
      ls_item-lgort = ls_ekpo-lgort.
      ls_item-matkl = ls_ekpo-matkl.
      ls_item-infnr = ls_ekpo-infnr.
      ls_item-menge = ls_ekpo-menge.
      ls_item-meins = ls_ekpo-meins.
      ls_item-bprme = ls_ekpo-bprme.
      ls_item-netpr = ls_ekpo-netpr.
      ls_item-peinh = ls_ekpo-peinh.
      ls_item-idnlf = ls_ekpo-idnlf.

      READ TABLE lt_ekkn INTO ls_ekkn
     WITH KEY ebeln = ls_ekpo-ebeln
              ebelp = ls_ekpo-ebelp.

      IF sy-subrc = 0.
        ls_item-kostl = ls_ekkn-kostl.
        ls_item-aufnr = ls_ekkn-aufnr.
        ls_item-sakto = ls_ekkn-sakto.
        ls_item-fkber = ls_ekkn-fkber.
        ls_item-geber = ls_ekkn-geber.
        ls_item-fistl = ls_ekkn-fistl.
        ls_item-vproz = ls_ekkn-vproz.
      ENDIF.

      READ TABLE lt_prcd_elements INTO ls_prcd_elements
  WITH KEY knumv = ls_ekko-knumv.

      IF sy-subrc = 0.
        ls_item-kschl = ls_prcd_elements-kschl.
        ls_item-kwert = ls_prcd_elements-kwert.
      ENDIF.

      " Lecture historique (EKBE)
      LOOP AT lt_ekbe INTO ls_ekbe
        WHERE ebeln = ls_ekpo-ebeln
          AND ebelp = ls_ekpo-ebelp.

        CASE ls_ekbe-vgabe.

          WHEN '1'.  " GR (MIGO)
            IF ls_ekbe-shkzg = 'H'.
              ls_item-gr_qty = ls_item-gr_qty - ls_ekbe-menge.
              ls_item-gr_amt = ls_item-gr_amt - ls_ekbe-dmbtr.
            ELSE.
              ls_item-gr_qty = ls_item-gr_qty + ls_ekbe-menge.
              ls_item-gr_amt = ls_item-gr_amt + ls_ekbe-dmbtr.
            ENDIF.

          WHEN '2'.  " IR (MIRO)
            IF ls_ekbe-shkzg = 'H'.
              ls_item-iv_qty = ls_item-iv_qty - ls_ekbe-menge.
              ls_item-iv_amt = ls_item-iv_amt - ls_ekbe-dmbtr.
            ELSE.
              ls_item-iv_qty = ls_item-iv_qty + ls_ekbe-menge.
              ls_item-iv_amt = ls_item-iv_amt + ls_ekbe-dmbtr.
            ENDIF.

        ENDCASE.

      ENDLOOP.

      " Calcul restant (3-way matching)
      ls_item-qty_remaining = ls_item-gr_qty - ls_item-iv_qty.

      IF ls_item-qty_remaining < 0." Si la valeur de la quantité restante est négative
        ls_item-qty_remaining = 0.
      ENDIF.

      ls_item-amt_remaining = ls_item-gr_amt - ls_item-iv_amt.

      IF ls_item-amt_remaining < 0.
        ls_item-amt_remaining = 0.
      ENDIF.

      APPEND ls_item TO gs_po-items.

    ENDLOOP.
    " Ajouter la commande complète
    APPEND gs_po TO gt_po.

  ENDLOOP.

ENDFORM.                    " F_GET_DATA
*&---------------------------------------------------------------------*
*&      Form  F_XML
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LV_XML  text
*----------------------------------------------------------------------*
FORM F_XML  USING    P_LV_XML TYPE string.

  CLEAR p_lv_xml.

  CONCATENATE '<?xml version="1.0" encoding="UTF-8"?>'
              cl_abap_char_utilities=>newline
              '<PurchaseOrders>'
              cl_abap_char_utilities=>newline
         INTO p_lv_xml.

  LOOP AT gt_po INTO gs_po.

    " Start of principal thread
    CONCATENATE p_lv_xml
                '  <PurchaseOrder>'
                cl_abap_char_utilities=>newline
           INTO p_lv_xml.

    CONCATENATE p_lv_xml
                '  <Header>'
                cl_abap_char_utilities=>newline
           INTO p_lv_xml.

    PERFORM build_tag USING 'EBELN'  gs_po-header-ebeln  CHANGING p_lv_xml.
    PERFORM build_tag USING 'BUKRS'  gs_po-header-bukrs  CHANGING p_lv_xml.
    PERFORM build_tag USING 'BSART'  gs_po-header-bsart  CHANGING p_lv_xml.
    PERFORM build_tag USING 'STATU'  gs_po-header-statu  CHANGING p_lv_xml.
    PERFORM build_tag USING 'AEDAT'  gs_po-header-aedat  CHANGING p_lv_xml.
    PERFORM build_tag USING 'BEDAT'  gs_po-header-bedat  CHANGING p_lv_xml.
    PERFORM build_tag USING 'LIFNR'  gs_po-header-lifnr  CHANGING p_lv_xml.
    PERFORM build_tag USING 'NAME1'  gs_po-header-name1  CHANGING p_lv_xml.
    PERFORM build_tag USING 'EKORG'  gs_po-header-ekorg  CHANGING p_lv_xml.
    PERFORM build_tag USING 'EKGRP'  gs_po-header-ekgrp  CHANGING p_lv_xml.
    PERFORM build_tag USING 'WAERS'  gs_po-header-waers  CHANGING p_lv_xml.

    CONCATENATE p_lv_xml
            '  </Header>'
            cl_abap_char_utilities=>newline
       INTO p_lv_xml.

    CONCATENATE p_lv_xml
            '  <Items>'
            cl_abap_char_utilities=>newline
       INTO p_lv_xml.

    LOOP AT gs_po-items INTO ls_item.

      CONCATENATE p_lv_xml
            '  <Item>'
            cl_abap_char_utilities=>newline
       INTO p_lv_xml.


      PERFORM build_tag USING 'EBELP' ls_item-ebelp CHANGING p_lv_xml.
      PERFORM build_tag USING 'MATNR' ls_item-matnr CHANGING p_lv_xml.
      PERFORM build_tag USING 'MAKTX' ls_item-maktx CHANGING p_lv_xml.
      PERFORM build_tag USING 'WERKS' ls_item-werks CHANGING p_lv_xml.
      PERFORM build_tag USING 'LGORT' ls_item-lgort CHANGING p_lv_xml.
      PERFORM build_tag USING 'MATKL' ls_item-matkl CHANGING p_lv_xml.
      PERFORM build_tag USING 'INFNR' ls_item-infnr CHANGING p_lv_xml.
      PERFORM build_tag USING 'MENGE' ls_item-menge CHANGING p_lv_xml.
      PERFORM build_tag USING 'MEINS' ls_item-meins CHANGING p_lv_xml.
      PERFORM build_tag USING 'BPRME' ls_item-bprme CHANGING p_lv_xml.
      PERFORM build_tag USING 'NETPR' ls_item-netpr CHANGING p_lv_xml.
      PERFORM build_tag USING 'PEINH' ls_item-peinh CHANGING p_lv_xml.
      PERFORM build_tag USING 'IDNLF' ls_item-idnlf CHANGING p_lv_xml.

      PERFORM build_tag USING 'KOSTL' ls_item-kostl CHANGING p_lv_xml.
      PERFORM build_tag USING 'AUFNR' ls_item-aufnr CHANGING p_lv_xml.
      PERFORM build_tag USING 'SAKTO' ls_item-sakto CHANGING p_lv_xml.
      PERFORM build_tag USING 'FKBER' ls_item-fkber CHANGING p_lv_xml.
      PERFORM build_tag USING 'GEBER' ls_item-geber CHANGING p_lv_xml.
      PERFORM build_tag USING 'FISTL' ls_item-fistl CHANGING p_lv_xml.
      PERFORM build_tag USING 'VPROZ' ls_item-vproz CHANGING p_lv_xml.

      PERFORM build_tag USING 'KSCHL' ls_item-kschl CHANGING p_lv_xml.
      PERFORM build_tag USING 'KWERT' ls_item-kwert CHANGING p_lv_xml.

      PERFORM build_tag USING 'TotalGRQuantity' ls_item-gr_qty CHANGING p_lv_xml.     " GR Total Qty
      PERFORM build_tag USING 'TotalInvoicedQuantity' ls_item-iv_qty CHANGING p_lv_xml. " Invoice Qty
      PERFORM build_tag USING 'RemainingQuantityToInvoice' ls_item-qty_remaining CHANGING p_lv_xml.

      PERFORM build_tag USING 'TotalGRAmount' ls_item-gr_amt CHANGING p_lv_xml.
      PERFORM build_tag USING 'TotalInvoicedAmount' ls_item-iv_amt CHANGING p_lv_xml.
      PERFORM build_tag USING 'RemainingAmountToInvoice' ls_item-amt_remaining CHANGING p_lv_xml.

      CONCATENATE p_lv_xml
            '  </Item>'
            cl_abap_char_utilities=>newline
       INTO p_lv_xml.

    ENDLOOP.

    CONCATENATE p_lv_xml
            '  </Items>'
            cl_abap_char_utilities=>newline
       INTO p_lv_xml.

    " End of principal thread
    CONCATENATE p_lv_xml
                '  </PurchaseOrder>'
                cl_abap_char_utilities=>newline
           INTO p_lv_xml.

  ENDLOOP.

  CONCATENATE p_lv_xml '</PurchaseOrders>' INTO p_lv_xml.

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
  CONCATENATE 'Commande_'lv_timestamp'.xml' INTO gv_filename RESPECTING BLANKS.
  CONCATENATE 'Commande_'lv_timestamp'.xml' INTO lv_file RESPECTING BLANKS.
  CONCATENATE 'Commande_'lv_timestamp1'.xml' INTO gv_filename1 RESPECTING BLANKS.

  "Chemin complet

  CONCATENATE gv_dir gv_filename INTO file_path RESPECTING BLANKS.

*&---------------------------------------------------------------------*
*&  Save XML data in AL11
*&---------------------------------------------------------------------*
  OPEN DATASET file_path
    FOR OUTPUT
    IN TEXT MODE
    ENCODING DEFAULT
    MESSAGE result_save_file.

  IF sy-subrc = 0.

    TRANSFER p_lv_xml TO file_path.

    CLOSE DATASET file_path.

  ENDIF.





ENDFORM.                    " F_XML


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
*&      Form  F_XSTRING
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LV_XML  text
*      <--P_XML_STRING  text
*----------------------------------------------------------------------*
FORM F_XSTRING  USING    P_LV_XML TYPE string
                CHANGING P_XML_STRING TYPE xstring.

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
  IF gt_po IS NOT INITIAL.
    WRITE: 'OK'.
  ELSE.
    WRITE: 'NO'.
  ENDIF.

  DESCRIBE TABLE gt_po LINES lv_lines.
  WRITE: / 'Nombre de factures récupérées : ', lv_lines COLOR COL_TOTAL INTENSIFIED OFF.

  WRITE: / 'Génération du XML : '.
  IF xml_string IS NOT INITIAL.
    WRITE: 'OK'.
  ELSE.
    WRITE: 'NO'.
  ENDIF.

  WRITE: / 'Statut Envoie mail :'.
  WRITE: / lv_mess.

ENDFORM.                    " F_DISP_RES
*&---------------------------------------------------------------------*
*&      Form  F_XML_BATCH
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LV_BATCH_SIZE  text
*----------------------------------------------------------------------*
FORM F_XML_BATCH  USING    P_BATCH_SIZE TYPE i.

  DATA: lv_xml          TYPE string,
        lv_filename     TYPE string,
        lv_file_path    TYPE string,
        lv_batch_number TYPE i VALUE 0,
        lt_po_batch     LIKE gt_po,
        ls_po           LIKE LINE OF gt_po,
        lv_tabix        TYPE sy-tabix.

  REFRESH lt_po_batch.
  lv_batch_number = 1.

  LOOP AT gt_po INTO ls_po.
    lv_tabix = sy-tabix.
    APPEND ls_po TO lt_po_batch.

    DATA lv_lines TYPE i.
    DESCRIBE TABLE lt_po_batch LINES lv_lines.
    DESCRIBE TABLE gt_po    LINES sy-tfill.   " ou garde lines() si toléré

    IF lv_lines = p_batch_size
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
FORM GENERATE_XML_ONE_BATCH  USING    pt_po_batch LIKE gt_po
                                      pv_batch_number TYPE i
                             CHANGING pv_file_path TYPE string.

  DATA: lv_xml         TYPE string,
        lv_date        TYPE char10,
        lv_time        TYPE char8,
        lv_time_clean  TYPE char8,
        lv_timestamp   TYPE char30,
        lv_filename    TYPE string,
        lv_msg         TYPE string,
        ls_po          LIKE LINE OF pt_po_batch,
        ls_item        LIKE LINE OF ls_po-items.

  CLEAR lv_xml.

  CONCATENATE
    '<?xml version="1.0" encoding="UTF-8"?>'
    cl_abap_char_utilities=>newline
    '<PurchaseOrders>'
    cl_abap_char_utilities=>newline
  INTO lv_xml.

  LOOP AT pt_po_batch INTO ls_po.
    CONCATENATE lv_xml '  <PurchaseOrder>' cl_abap_char_utilities=>newline INTO lv_xml.
    CONCATENATE lv_xml '  <Header>' cl_abap_char_utilities=>newline INTO lv_xml.

    PERFORM build_tag USING 'EBELN'  gs_po-header-ebeln  CHANGING lv_xml.
    PERFORM build_tag USING 'BUKRS'  gs_po-header-bukrs  CHANGING lv_xml.
    PERFORM build_tag USING 'BSART'  gs_po-header-bsart  CHANGING lv_xml.
    PERFORM build_tag USING 'STATU'  gs_po-header-statu  CHANGING lv_xml.
    PERFORM build_tag USING 'AEDAT'  gs_po-header-aedat  CHANGING lv_xml.
    PERFORM build_tag USING 'BEDAT'  gs_po-header-bedat  CHANGING lv_xml.
    PERFORM build_tag USING 'LIFNR'  gs_po-header-lifnr  CHANGING lv_xml.
    PERFORM build_tag USING 'NAME1'  gs_po-header-name1  CHANGING lv_xml.
    PERFORM build_tag USING 'EKORG'  gs_po-header-ekorg  CHANGING lv_xml.
    PERFORM build_tag USING 'EKGRP'  gs_po-header-ekgrp  CHANGING lv_xml.
    PERFORM build_tag USING 'WAERS'  gs_po-header-waers  CHANGING lv_xml.

    CONCATENATE lv_xml '  </Header>' cl_abap_char_utilities=>newline INTO lv_xml.
    CONCATENATE lv_xml '  <Items>' cl_abap_char_utilities=>newline INTO lv_xml.

    LOOP AT ls_po-items INTO ls_item.
      CONCATENATE lv_xml '    <Item>' cl_abap_char_utilities=>newline INTO lv_xml.

      PERFORM build_tag USING 'EBELP' ls_item-ebelp CHANGING lv_xml.
      PERFORM build_tag USING 'MATNR' ls_item-matnr CHANGING lv_xml.
      PERFORM build_tag USING 'MAKTX' ls_item-maktx CHANGING lv_xml.
      PERFORM build_tag USING 'WERKS' ls_item-werks CHANGING lv_xml.
      PERFORM build_tag USING 'LGORT' ls_item-lgort CHANGING lv_xml.
      PERFORM build_tag USING 'MATKL' ls_item-matkl CHANGING lv_xml.
      PERFORM build_tag USING 'INFNR' ls_item-infnr CHANGING lv_xml.
      PERFORM build_tag USING 'MENGE' ls_item-menge CHANGING lv_xml.
      PERFORM build_tag USING 'MEINS' ls_item-meins CHANGING lv_xml.
      PERFORM build_tag USING 'BPRME' ls_item-bprme CHANGING lv_xml.
      PERFORM build_tag USING 'NETPR' ls_item-netpr CHANGING lv_xml.
      PERFORM build_tag USING 'PEINH' ls_item-peinh CHANGING lv_xml.
      PERFORM build_tag USING 'IDNLF' ls_item-idnlf CHANGING lv_xml.

      PERFORM build_tag USING 'KOSTL' ls_item-kostl CHANGING lv_xml.
      PERFORM build_tag USING 'AUFNR' ls_item-aufnr CHANGING lv_xml.
      PERFORM build_tag USING 'SAKTO' ls_item-sakto CHANGING lv_xml.
      PERFORM build_tag USING 'FKBER' ls_item-fkber CHANGING lv_xml.
      PERFORM build_tag USING 'GEBER' ls_item-geber CHANGING lv_xml.
      PERFORM build_tag USING 'FISTL' ls_item-fistl CHANGING lv_xml.
      PERFORM build_tag USING 'VPROZ' ls_item-vproz CHANGING lv_xml.

      PERFORM build_tag USING 'KSCHL' ls_item-kschl CHANGING lv_xml.
      PERFORM build_tag USING 'KWERT' ls_item-kwert CHANGING lv_xml.

      PERFORM build_tag USING 'TotalGRQuantity' ls_item-gr_qty CHANGING lv_xml.     " GR Total Qty
      PERFORM build_tag USING 'TotalInvoicedQuantity' ls_item-iv_qty CHANGING lv_xml. " Invoice Qty
      PERFORM build_tag USING 'RemainingQuantityToInvoice' ls_item-qty_remaining CHANGING lv_xml.

      PERFORM build_tag USING 'TotalGRAmount' ls_item-gr_amt CHANGING lv_xml.
      PERFORM build_tag USING 'TotalInvoicedAmount' ls_item-iv_amt CHANGING lv_xml.
      PERFORM build_tag USING 'RemainingAmountToInvoice' ls_item-amt_remaining CHANGING lv_xml.

      CONCATENATE lv_xml '    </Item>' cl_abap_char_utilities=>newline INTO lv_xml.


    ENDLOOP.

    CONCATENATE lv_xml '  </Items>' cl_abap_char_utilities=>newline INTO lv_xml.
    CONCATENATE lv_xml '  </PurchaseOrder>' cl_abap_char_utilities=>newline INTO lv_xml.

  ENDLOOP.
  CONCATENATE lv_xml '</PurchaseOrders>' INTO lv_xml.

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

  CONCATENATE 'Commande_' lv_timestamp
              '_part' lv_batch_text
              '.xml'
         INTO lv_filename RESPECTING BLANKS.

  CONCATENATE 'Commande_' lv_timestamp1
             '_part' lv_batch_text
             '.xml'
        INTO gv_filename1 RESPECTING BLANKS.

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
     IV_SUBJECT_BASE       = 'Bon de commande du '
*       IV_BODY               =
     IV_FILENAME           = gv_filename1
      IV_INTERFACE          = 'Bon de commande'
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