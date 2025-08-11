CREATE OR REPLACE FUNCTION `hc-5c7132af39e94c9ea03d2710265.vault_functions.encrypt_credit_card`(credit_card STRING)
RETURNS STRING
REMOTE WITH CONNECTION `786265264300.us-central1.vault-connection`
OPTIONS (
  endpoint = 'https://vault-transform-function-cvb4eibhuq-uc.a.run.app',
  max_batching_rows = 100
);
