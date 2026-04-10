ZFLOWIE_GET_LAST_NEW_DOCUMENT

FUNCTION zflowie_get_last_new_document.
*"----------------------------------------------------------------------
*"*"Interface locale :
*"  IMPORTING
*"     VALUE(IV_OBJECTCLAS) TYPE  CDOBJECTCL
*"  EXPORTING
*"     VALUE(EV_CHANGENR) TYPE  CDCHANGENR
*"  TABLES
*"      IT_CDHDR STRUCTURE  CDHDR OPTIONAL
*"----------------------------------------------------------------------

**& ----------------------------
**& DATE   : 03.04.2026
**& Author : SAPERP Solutions
**& Object : This fonction gets last object created or changed
**& ----------------------------

  DATA:
   lv_changenr   TYPE cdchangenr,
   lv_udate_low  TYPE  udate.

**& ------------------------------
**& ----> Step 1 : Find the last number of CDHDR of the object [iv_objectclas]
**& ----> Stored on FLOWIE Param table
**& ------------------------------
  SELECT SINGLE last_changenr
   INTO lv_changenr
     FROM zflowie_chdr_key
       WHERE
         objectclas = iv_objectclas .

  IF sy-subrc NE 0.   "/*not found
    lv_changenr  = 0.
    lv_udate_low = sy-datum - 10 * 365 .                    "/*1 year
  ELSE.
    lv_udate_low = sy-datum - 180. "/*six month ago
    ev_changenr  = lv_changenr.
  ENDIF.

**& --------
**& Manage exception for IDOC objects :
**& -----------
  CHECK iv_objectclas NE 'IDOC'.

**& ------------------------------
**& ----> Step 2 :Collect all objects number changed or creatred
**& ------------------------------
  SELECT *
   INTO TABLE it_cdhdr
    FROM cdhdr
     WHERE
       udate BETWEEN lv_udate_low AND sy-datum AND
       objectclas = iv_objectclas  AND
       changenr  >  lv_changenr .

  SORT it_cdhdr BY objectid changenr DESCENDING.
  DELETE ADJACENT DUPLICATES FROM it_cdhdr COMPARING objectid changenr.
ENDFUNCTION.

--------------------------------------------------------------------------------
ZFLOWIE_SET_LAST_DOC_NUMBER
FUNCTION zflowie_set_last_doc_number.
*"----------------------------------------------------------------------
*"*"Interface locale :
*"  IMPORTING
*"     REFERENCE(IV_OBJECTCLAS) TYPE  CDOBJECTCL
*"     REFERENCE(IV_LAST_OBJECTID) TYPE  CDOBJECTV
*"----------------------------------------------------------------------

**& ----------------------------
**& DATE   : 03.04.2026
**& Author : SAPERP Solutions
**& Object : This fonction set the last object extracted on table flowie_chdr_key
**& ----------------------------

  TABLES :  zflowie_chdr_key.

  DATA:
   lt_zflowie_chdr_key  TYPE zflowie_chdr_key,
   lv_curr_changenr     TYPE cdchangenr,
   lt_cdhdr             TYPE TABLE OF cdhdr,
   ls_cdhdr             TYPE cdhdr.

**& ----->  Extracting current change number of object

IF IV_OBJECTCLAS NE 'IDOC'.

  SELECT *
    INTO TABLE lt_cdhdr
    FROM cdhdr
     WHERE objectclas = iv_objectclas AND
           objectid   = iv_last_objectid.

  CHECK lt_cdhdr[] IS NOT INITIAL.

  SORT lt_cdhdr  BY changenr DESCENDING.
  READ TABLE lt_cdhdr INDEX 1 INTO ls_cdhdr.

  lv_curr_changenr  =  ls_cdhdr-changenr.
ELSE.
  lv_curr_changenr = iv_last_objectid.
ENDIF.

**& ----> Step 1 : initialize value
  lt_zflowie_chdr_key-objectclas = iv_objectclas.
  lt_zflowie_chdr_key-last_changenr = lv_curr_changenr .

**& ----> Step 2 : inserting value
  MODIFY zflowie_chdr_key FROM lt_zflowie_chdr_key.

**& ----> Step 3 : commiting transaction
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = 'X'.

ENDFUNCTION.

------------------------------------------------------------------------------
table : ZFLOWIE_CHDR_KEY

MANDANT	MANDT	CLNT	3	0	Mandant
OBJECTCLAS	CDOBJECTCL	CHAR	15	0	Classe d'objets
LAST_CHANGENR	CDCHANGENR	CHAR	10	0	Nº de modification du document



