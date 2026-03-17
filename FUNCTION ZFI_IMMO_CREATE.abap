FUNCTION ZFI_IMMO_CREATE.
*"--------------------------------------------------------------------
*"*"Interface locale :
*"  IMPORTING
*"     VALUE(INPUT_METHOD) LIKE  BDWFAP_PAR-INPUTMETHD
*"     VALUE(MASS_PROCESSING) LIKE  BDWFAP_PAR-MASS_PROC
*"  EXPORTING
*"     VALUE(WORKFLOW_RESULT) LIKE  BDWF_PARAM-RESULT
*"     VALUE(APPLICATION_VARIABLE) LIKE  BDWF_PARAM-APPL_VAR
*"     VALUE(IN_UPDATE_TASK) LIKE  BDWFAP_PAR-UPDATETASK
*"     VALUE(CALL_TRANSACTION_DONE) LIKE  BDWFAP_PAR-CALLTRANS
*"  TABLES
*"      IDOC_CONTRL STRUCTURE  EDIDC
*"      IDOC_DATA STRUCTURE  EDIDD
*"      IDOC_STATUS STRUCTURE  BDIDOCSTAT
*"      RETURN_VARIABLES STRUCTURE  BDWFRETVAR
*"      SERIALIZATION_INFO STRUCTURE  BDI_SER
*"  EXCEPTIONS
*"      WRONG_FUNCTION_CALLED
*"--------------------------------------------------------------------
*----------------------------------------------------------------------*
*  Date : 09.02.2026                                                   *
*  This function module is to create asset (Fiche IMMMO)               *
*       using specific IDoc named ZFI_IMMO_CREATE                      *
*----------------------------------------------------------------------*

  DATA:
    e1scu_cre               LIKE e1scu_cre,
    e1bpscunew              LIKE e1bpscunew,
    e1bpparex               LIKE e1bpparex,

*--- variables for idoc segments --------------------------------------*
    zfi_immo_key            TYPE zfi_immo_key,
    zfi_immo_general_data   TYPE zfi_immo_general_data,
    zfi_immo_general_data_x TYPE zfi_immo_general_data_x,

*--- variables for bapi -----------------------------------------------*
    ls_key                  TYPE bapi1022_key,
    ls_general_data         TYPE bapi1022_feglg001,
    ls_general_data_x       TYPE bapi1022_feglg001x,

    ls_asset_created        TYPE bapi1022_reference,
    ls_return               TYPE bapiret2,
*---------------------------------------------------------------------*

    customernumber          LIKE
      bapiscudat-customerid,
    customer_data           LIKE
       bapiscunew,
    test_run                LIKE
            bapiscuaux-testrun,

    extension_in            LIKE bapiparex
                  OCCURS 0 WITH HEADER LINE,
    return                  LIKE bapiret2
                        OCCURS 0 WITH HEADER LINE,

    t_edidd                 LIKE edidd OCCURS 0 WITH HEADER LINE,
    bapi_retn_info          LIKE bapiret2 OCCURS 0 WITH HEADER LINE.

  DATA: error_flag,
        bapi_idoc_status LIKE bdidocstat-status.

  in_update_task = 'X'.
  CLEAR call_transaction_done.
* check if the function is called correctly                            *
  READ TABLE idoc_contrl INDEX 1.
  IF sy-subrc <> 0.
    EXIT.
  ELSEIF idoc_contrl-mestyp <> 'ZFI_IMMO'.      " confirm message type
    RAISE wrong_function_called.
  ENDIF.

* go through all IDocs                                                 *
  LOOP AT idoc_contrl.
*   select segments belonging to one IDoc                              *
    REFRESH t_edidd.
    LOOP AT idoc_data WHERE docnum = idoc_contrl-docnum.
      APPEND idoc_data TO t_edidd.
    ENDLOOP.

*   through all segments of this IDoc                                  *
    CLEAR error_flag.
    REFRESH bapi_retn_info.
    CATCH SYSTEM-EXCEPTIONS conversion_errors = 1.
      LOOP AT t_edidd INTO idoc_data.

        CASE idoc_data-segnam.

*------ assign idoc data to variables for bapi ------------------------*
          WHEN 'ZFI_IMMO_KEY'.
            MOVE idoc_data-sdata TO zfi_immo_key.

*           Company code
            ls_key-companycode = zfi_immo_key-companycode.


          WHEN 'ZFI_IMMO_GENERAL_DATA'.
            MOVE idoc_data-sdata TO zfi_immo_general_data.

*           Asset class
            ls_general_data-assetclass = zfi_immo_general_data-assetclass.
*           Asset Description
            ls_general_data-descript = zfi_immo_general_data-descript.


          WHEN 'ZFI_IMMO_GENERAL_DATA_X'.
            MOVE idoc_data-sdata TO zfi_immo_general_data_x.

            ls_general_data_x-assetclass = zfi_immo_general_data_x-assetclass.
            ls_general_data_x-descript = zfi_immo_general_data_x-descript.

*----------------------------------------------------------------------*

        ENDCASE.

      ENDLOOP.
    ENDCATCH.
    IF sy-subrc = 1.
*     write IDoc status-record as error and continue                   *
      CLEAR bapi_retn_info.
      bapi_retn_info-type   = 'E'.
      bapi_retn_info-id     = 'B1'.
      bapi_retn_info-number = '527'.
      bapi_retn_info-message_v1 = idoc_data-segnam.
      bapi_idoc_status      = '51'.
      PERFORM idoc_status_flcustomer_createf
              TABLES t_edidd
                     idoc_status
                     return_variables
               USING idoc_contrl
                     bapi_retn_info
                     bapi_idoc_status
                     workflow_result.
      CONTINUE.
    ENDIF.
*   call BAPI-function in this system           *
    CALL FUNCTION 'BAPI_FIXEDASSET_CREATE1'
      EXPORTING
        key          = ls_key
        generaldata  = ls_general_data
        generaldatax = ls_general_data_x
      IMPORTING
        assetcreated = ls_asset_created
        return       = ls_return.

    IF sy-subrc <> 0.
*     write IDoc status-record as error                                *
      CLEAR bapi_retn_info.
      bapi_retn_info-type       = 'E'.
      bapi_retn_info-id         = sy-msgid.
      bapi_retn_info-number     = sy-msgno.
      bapi_retn_info-message_v1 = sy-msgv1.
      bapi_retn_info-message_v2 = sy-msgv2.
      bapi_retn_info-message_v3 = sy-msgv3.
      bapi_retn_info-message_v4 = sy-msgv4.
      bapi_idoc_status          = '51'.
      PERFORM idoc_status_flcustomer_createf
              TABLES t_edidd
                     idoc_status
                     return_variables
               USING idoc_contrl
                     bapi_retn_info
                     bapi_idoc_status
                     workflow_result.
    ELSE.
      MOVE-CORRESPONDING ls_return TO return.
      LOOP AT return.
        IF NOT return IS INITIAL.
          CLEAR bapi_retn_info.
          MOVE-CORRESPONDING return TO bapi_retn_info.
          IF return-type = 'A' OR return-type = 'E'.
            error_flag = 'X'.
          ENDIF.
          APPEND bapi_retn_info.
        ENDIF.
      ENDLOOP.
      LOOP AT bapi_retn_info.
*       write IDoc status-record                                       *
        IF error_flag IS INITIAL.
          bapi_idoc_status = '53'.
        ELSE.
          bapi_idoc_status = '51'.
          IF bapi_retn_info-type = 'S'.
            CONTINUE.
          ENDIF.
        ENDIF.
        PERFORM idoc_status_flcustomer_createf
                TABLES t_edidd
                       idoc_status
                       return_variables
                 USING idoc_contrl
                       bapi_retn_info
                       bapi_idoc_status
                       workflow_result.
      ENDLOOP.
      IF sy-subrc <> 0.
*      'RETURN' is empty write idoc status-record as successful        *
        CLEAR bapi_retn_info.
        bapi_retn_info-type       = 'S'.
        bapi_retn_info-id         = ls_return-id.
        bapi_retn_info-number     = ls_return-number.
        bapi_retn_info-message_v1 = ls_return-message_v1.
        bapi_retn_info-message_v2 = ls_return-message_v2.
        bapi_retn_info-message_v3 = ls_return-message_v3.
        bapi_idoc_status          = '53'.
        PERFORM idoc_status_flcustomer_createf
                TABLES t_edidd
                       idoc_status
                       return_variables
                 USING idoc_contrl
                       bapi_retn_info
                       bapi_idoc_status
                       workflow_result.
      ENDIF.
      IF error_flag IS INITIAL.
*       write linked object keys                                       *
        CLEAR return_variables.
        return_variables-wf_param = 'Appl_Objects'.
        READ TABLE return_variables WITH KEY wf_param = 'Appl_Objects'.
        MOVE ls_asset_created-asset
          TO return_variables-doc_number+00.
        IF sy-subrc <> 0.
          APPEND return_variables.
        ELSE.
          MODIFY return_variables INDEX sy-tabix.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDLOOP.                             " idoc_contrl






ENDFUNCTION.


* subroutine writing IDoc status-record                                *
FORM idoc_status_flcustomer_createf
     TABLES idoc_data    STRUCTURE  edidd
            idoc_status  STRUCTURE  bdidocstat
            r_variables  STRUCTURE  bdwfretvar
      USING idoc_contrl  LIKE  edidc
            VALUE(retn_info) LIKE   bapiret2
            status       LIKE  bdidocstat-status
            wf_result    LIKE  bdwf_param-result.

  CLEAR idoc_status.
  idoc_status-docnum   = idoc_contrl-docnum.
  idoc_status-msgty    = retn_info-type.
  idoc_status-msgid    = retn_info-id.
  idoc_status-msgno    = retn_info-number.
  idoc_status-appl_log = retn_info-log_no.
  idoc_status-msgv1    = retn_info-message_v1.
  idoc_status-msgv2    = retn_info-message_v2.
  idoc_status-msgv3    = retn_info-message_v3.
  idoc_status-msgv4    = retn_info-message_v4.
  idoc_status-repid    = sy-repid.
  idoc_status-status   = status.

  CASE retn_info-parameter.
    WHEN 'EXTENSIONIN'
      OR 'EXTENSION_IN'
         .
      LOOP AT idoc_data WHERE
                        segnam = 'E1BPPAREX'.
        retn_info-row = retn_info-row - 1.
        IF retn_info-row <= 0.
          idoc_status-segnum = idoc_data-segnum.
          idoc_status-segfld = retn_info-field.
          EXIT.
        ENDIF.
      ENDLOOP.
    WHEN 'CUSTOMERDATA'
      OR 'CUSTOMER_DATA'
         .
      LOOP AT idoc_data WHERE
                        segnam = 'E1BPSCUNEW'.
        retn_info-row = retn_info-row - 1.
        IF retn_info-row <= 0.
          idoc_status-segnum = idoc_data-segnum.
          idoc_status-segfld = retn_info-field.
          EXIT.
        ENDIF.
      ENDLOOP.
    WHEN 'TESTRUN'
      OR 'TEST_RUN'
         .
      LOOP AT idoc_data WHERE
                        segnam = 'E1SCU_CRE'.
        retn_info-row = retn_info-row - 1.
        IF retn_info-row <= 0.
          idoc_status-segnum = idoc_data-segnum.
          idoc_status-segfld = retn_info-field.
          EXIT.
        ENDIF.
      ENDLOOP.
    WHEN OTHERS.

  ENDCASE.

  INSERT idoc_status INDEX 1.

  IF idoc_status-status = '51'.
    wf_result = '99999'.
    r_variables-wf_param   = 'Error_IDOCs'.
    r_variables-doc_number = idoc_contrl-docnum.
    READ TABLE r_variables FROM r_variables.
    IF sy-subrc <> 0.
      APPEND r_variables.
    ENDIF.
  ELSEIF idoc_status-status = '53'.
    CLEAR wf_result.
    r_variables-wf_param = 'Processed_IDOCs'.
    r_variables-doc_number = idoc_contrl-docnum.
    READ TABLE r_variables FROM r_variables.
    IF sy-subrc <> 0.
      APPEND r_variables.
    ENDIF.
    r_variables-wf_param = 'Appl_Object_Type'.
    r_variables-doc_number = 'SCUSTOMER'.
    READ TABLE r_variables FROM r_variables.
    IF sy-subrc <> 0.
      APPEND r_variables.
    ENDIF.
  ENDIF.

ENDFORM.                               " IDOC_STATUS_FLCUSTOMER_CREATEF