FUNCTION ZMM_GET_MATERIAL_STOCK_VALUES.
*"----------------------------------------------------------------------
*"*"Interface locale :
*"  IMPORTING
*"     VALUE(IV_BUKRS) TYPE  T001-BUKRS OPTIONAL
*"     VALUE(IV_WERKS) TYPE  WERKS_D OPTIONAL
*"     VALUE(IV_LGORT) TYPE  LGORT_D OPTIONAL
*"     VALUE(IV_CHARG) TYPE  CHARG_D OPTIONAL
*"     VALUE(IT_MATNR_RANGE) TYPE  ZMM_STR_MAT_TT OPTIONAL
*"  EXPORTING
*"     VALUE(EV_ERROR) TYPE  BOOLEAN
*"     VALUE(EV_MESSAGE) TYPE  BAPI_MSG
*"     VALUE(ET_STOCK_VALUE) TYPE  ZMM_STOCK_VALUE_TT
*"     VALUE(ET_RETURN) TYPE  BAPIRET2_T
*"----------------------------------------------------------------------


  DATA: ls_input TYPE ZMM_STR_MAT.

  DATA: ls_range LIKE LINE OF it_matnr_range.

  TYPES: BEGIN OF ty_mard_stock,
           matnr TYPE mard-matnr,
           werks TYPE mard-werks,
           lgort TYPE mard-lgort,
           labst TYPE mard-labst,
           insme TYPE mard-insme,
           einme TYPE mard-einme,
           speme TYPE mard-speme,
           retme TYPE mard-retme,
         END OF ty_mard_stock.

  DATA: lt_mard TYPE STANDARD TABLE OF ty_mard_stock
                     WITH NON-UNIQUE DEFAULT KEY.
  TYPES: BEGIN OF ty_mbew_val,
         matnr TYPE mbew-matnr,
         bwkey TYPE mbew-bwkey,
         bwtar TYPE mbew-bwtar,
         vprsv TYPE mbew-vprsv,
         stprs TYPE mbew-stprs,
         verpr TYPE mbew-verpr,
         peinh TYPE mbew-peinh,
         lbkum TYPE mbew-lbkum,
         salk3 TYPE mbew-salk3,
         bklas TYPE mbew-bklas,
       END OF ty_mbew_val.

  DATA: lt_mbew TYPE STANDARD TABLE OF ty_mbew_val
                     WITH NON-UNIQUE DEFAULT KEY.

  DATA: ls_stock         TYPE zmm_stock_value,
          lv_bwkey         TYPE bwkey,
          lv_currency      TYPE waers,
          lv_price         TYPE p DECIMALS 5,
          lv_peinh         TYPE peinh,
          ls_return        TYPE bapiret2.

  FIELD-SYMBOLS: <fs_mard> LIKE LINE OF lt_mard,
                 <fs_mbew> LIKE LINE OF lt_mbew,
                 <ls_range> LIKE LINE OF IT_MATNR_RANGE.

  CLEAR: ev_error, ev_message.
  REFRESH: et_stock_value, et_return.

  " Contrôler les valeurs de matériel

  " 1. Optionnel : si SIGN et OPTION sont vides → ligne inutile ?

  LOOP AT it_matnr_range ASSIGNING <ls_range>.

    IF <ls_range>-sign is INITIAL or <ls_range>-option IS INITIAL and ( <ls_range>-high IS NOT INITIAL
      or <ls_range>-low IS NOT INITIAL ).

      ev_message = 'Attention, les valeurs saisies dans le plage de valeur de matériel ne sont pas cohérentes'.
      RETURN.

    ENDIF.

  ENDLOOP.

  DELETE it_matnr_range WHERE option IS INITIAL.
  DELETE it_matnr_range WHERE sign IS INITIAL.

  LOOP AT it_matnr_range ASSIGNING <ls_range>.


    " 2. Vérification du champ SIGN
    IF <ls_range>-sign IS NOT INITIAL.
      IF <ls_range>-sign <> 'I' AND <ls_range>-sign <> 'E'.
        ev_message = 'SIGN doit être I ou E'.
        RETURN.
      ENDIF.
    ENDIF.   " si vide → souvent toléré, mais parfois forcé à 'I'

    " 3. Vérification du champ OPTION
    IF <ls_range>-option IS NOT INITIAL.

      CASE <ls_range>-option.
        WHEN 'EQ' OR 'NE' OR 'GT' OR 'GE' OR 'LT' OR 'LE' OR 'CP' OR 'NP'.
          " Cas "single value" ou pattern → HIGH doit être vide
          IF <ls_range>-high IS NOT INITIAL.
            ev_message = 'Pour cette valeur de option, le champ HIGH doit être vide'.
            RETURN.
          ENDIF.

        WHEN 'BT' OR 'NB'.
          " Cas intervalle → HIGH obligatoire
          IF <ls_range>-high IS INITIAL.
            ev_message = 'Pour option = BT/NB, HIGH est obligatoire'.
            RETURN.
          ENDIF.

          " Bonus : souvent on vérifie aussi low <= high (selon le type de données)
          IF <ls_range>-low > <ls_range>-high.
            ev_message = 'LOW doit être <= HIGH pour intervalle' .
            RETURN.
          ENDIF.

        WHEN OTHERS.
          CONCATENATE 'Option non supportée :' <ls_range>-option INTO ev_message SEPARATED BY space.
      ENDCASE.

    ELSE.
      " option vide → souvent erreur, car une ligne sans option n'a pas de sens
      IF <ls_range>-low IS NOT INITIAL OR <ls_range>-high IS NOT INITIAL.
        ev_message = 'OPTION est obligatoire quand LOW/HIGH est rempli'.
        RETURN.
      ENDIF.
    ENDIF.

  ENDLOOP.



  " Conversion des champs
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = IV_WERKS
    IMPORTING
      output = IV_WERKS.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = IV_LGORT
    IMPORTING
      output = IV_LGORT.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = IV_CHARG
    IMPORTING
      output = IV_CHARG.

  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = IV_BUKRS
    IMPORTING
      output = IV_BUKRS.

  LOOP AT it_matnr_range INTO ls_range.
    IF ls_range-option = 'BT' OR ls_range-option = 'EQ'.
      CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
        EXPORTING
          input  = ls_range-low
        IMPORTING
          output = ls_range-low.
      IF ls_range-high IS NOT INITIAL.
        CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
          EXPORTING
            input  = ls_range-high
          IMPORTING
            output = ls_range-high.
      ENDIF.
      MODIFY it_matnr_range FROM ls_range.
    ENDIF.
  ENDLOOP.


  " Contrôle usine obligatoire
  IF iv_werks IS INITIAL.
    ev_error = 'X'.
    ev_message = 'Usine (WERKS) obligatoire pour la valorisation'.
    ls_return-type    = 'E'.
    ls_return-id      = 'ZMM'.
    ls_return-number  = '001'.
    ls_return-message = ev_message.
    APPEND ls_return TO et_return.
    RETURN.
  ENDIF.

  lv_bwkey = iv_werks.

  " Devise
  IF iv_bukrs IS NOT INITIAL.
    SELECT SINGLE waers FROM t001 INTO lv_currency WHERE bukrs = iv_bukrs.
    IF sy-subrc <> 0.
      ev_error = 'X'.
      ls_return-type    = 'E'.
      ls_return-id      = 'ZMM'.
      ls_return-number  = '002'.
      CONCATENATE 'Société' iv_bukrs 'non trouvée' INTO ev_message SEPARATED BY space.
      ls_return-message = ev_message.
      APPEND ls_return TO et_return.
      RETURN.
    ENDIF.
  ELSE.
    lv_currency = 'EUR'.   " Valeur par défaut
  ENDIF.

  " Avertissement si pas de restriction matériel
  IF it_matnr_range IS INITIAL.
    ls_return-type    = 'W'.
    ls_return-id      = 'ZMM'.
    ls_return-number  = '003'.
    ls_return-message = 'Aucun matériel spécifié → sélection volumineuse possible'.
    APPEND ls_return TO et_return.
  ENDIF.

  " 1. Stocks quantitatifs (MARD)
  IF it_matnr_range[] IS NOT INITIAL.

    IF iv_lgort IS INITIAL.
      SELECT matnr werks lgort labst insme einme speme retme
        FROM mard
        INTO TABLE lt_mard
        WHERE matnr in it_matnr_range
          AND werks = iv_werks
          AND ( labst > 0 OR insme > 0 OR speme > 0 OR einme > 0 OR retme > 0 ).
    ELSE.
      SELECT matnr werks lgort labst insme einme speme retme
        FROM mard
        INTO TABLE lt_mard
        WHERE matnr in it_matnr_range
          AND werks = iv_werks
          AND lgort = iv_lgort
          AND ( labst > 0 OR insme > 0 OR speme > 0 OR einme > 0 OR retme > 0 ).
    ENDIF.
  ELSE.

    IF iv_lgort IS INITIAL.
      SELECT matnr werks lgort labst insme einme speme retme
        FROM mard
        INTO TABLE lt_mard
        WHERE werks = iv_werks
          AND ( labst > 0 OR insme > 0 OR speme > 0 OR einme > 0 OR retme > 0 ).
    ELSE.
      SELECT matnr werks lgort labst insme einme speme retme
        FROM mard
        INTO TABLE lt_mard
        WHERE  werks = iv_werks
          AND lgort = iv_lgort
          AND ( labst > 0 OR insme > 0 OR speme > 0 OR einme > 0 OR retme > 0 ).
    ENDIF.

  ENDIF.

  IF lt_mard IS INITIAL.
    ev_message = 'Aucun matériel trouvé dans nos données'.
    ls_return-type    = 'I'.
    ls_return-id      = 'ZMM'.
    ls_return-number  = '005'.
    ls_return-message = ev_message.
    APPEND ls_return TO et_return.
    RETURN.
  ENDIF.

  SORT lt_mard BY matnr werks lgort.
  DELETE ADJACENT DUPLICATES FROM lt_mard COMPARING matnr werks lgort.

  " 2. Valorisation (MBEW) - on prend seulement les enregistrements sans split (BWTAR vide)
  SELECT matnr bwkey bwtar vprsv stprs verpr peinh lbkum salk3 bklas
    FROM mbew
    INTO TABLE lt_mbew
    FOR ALL ENTRIES IN lt_mard
    WHERE matnr = lt_mard-matnr
      AND bwkey = lv_bwkey
      AND bwtar = ' '.

  SORT lt_mbew BY matnr bwkey bwtar.

                                                            " 3. Calcul
  LOOP AT lt_mard ASSIGNING <fs_mard>.

    CLEAR ls_stock.

    ls_stock-matnr     = <fs_mard>-matnr.
    ls_stock-werks     = <fs_mard>-werks.
    ls_stock-lgort     = <fs_mard>-lgort.

    ls_stock-labst     = <fs_mard>-labst.
    ls_stock-total_qty = <fs_mard>-labst + <fs_mard>-insme + <fs_mard>-speme
                       + <fs_mard>-einme + <fs_mard>-retme.

    READ TABLE lt_mbew ASSIGNING <fs_mbew>
      WITH KEY matnr = <fs_mard>-matnr
               bwkey = lv_bwkey
               bwtar = ' '
      BINARY SEARCH.

    IF sy-subrc = 0.

      ls_stock-vprsv    = <fs_mbew>-vprsv.
      ls_stock-bklas    = <fs_mbew>-bklas.
      ls_stock-currency = lv_currency.

      lv_peinh = <fs_mbew>-peinh.
      IF lv_peinh IS INITIAL.
        lv_peinh = 1.
      ENDIF.

      IF <fs_mbew>-vprsv = 'S'.
        lv_price = <fs_mbew>-stprs / lv_peinh.
      ELSE.
        lv_price = <fs_mbew>-verpr / lv_peinh.
      ENDIF.

      ls_stock-price_unit = lv_price.

      " Méthode la plus fiable : utiliser SALK3 / LBKUM si LBKUM > 0
      IF <fs_mbew>-lbkum > 0.
        ls_stock-stock_value = ( ls_stock-total_qty / <fs_mbew>-lbkum ) * <fs_mbew>-salk3.
      ELSE.
        " Fallback : quantité * prix unitaire (cas où LBKUM n'est pas à jour)
        ls_stock-stock_value = ls_stock-total_qty * lv_price.
      ENDIF.

    ELSE.
      " Pas de valorisation → on met à 0 mais on peut ajouter un message warning si besoin
      ls_stock-price_unit  = 0.
      ls_stock-stock_value = 0.

      ls_return-type    = 'W'.
      ls_return-id      = 'ZMM'.
      ls_return-number  = '006'.
      CONCATENATE 'Pas de valorisation pour article' <fs_mard>-matnr 'usine' iv_werks INTO ls_return-message SEPARATED BY space.
      APPEND ls_return TO et_return.
    ENDIF.

    APPEND ls_stock TO et_stock_value.

  ENDLOOP.

  SORT et_stock_value BY matnr werks lgort.

  IF et_stock_value IS INITIAL.
    ev_message = 'Aucune donnée valorisée trouvée'.
    ls_return-type    = 'I'.
    ls_return-id      = 'ZMM'.
    ls_return-number  = '004'.
    ls_return-message = ev_message.
    APPEND ls_return TO et_return.
  ENDIF.



ENDFUNCTION.