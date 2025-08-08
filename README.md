# Hashicorp Vault Transform Secret Engine with BigQuery

## problem

The Hashicorp Vault Transform Secret Engine is a powerful tool for managing sensitive data transformations. Raw data is send to Vault Transform Secret Engine, goes through a Format Preserving Encryption (FPE) process, and returns the encrypted data, which is then saved in database. For example, a credit card number can be transformed into an encrypted format that retains the original format's structure, allowing for secure storage and processing without exposing sensitive information.

BigQuery is a fully managed, serverless data warehouse that enables scalable analysis over petabytes of data. Operators use BigQuery to query and analyze large datasets efficiently. for example, Operators from Fraud Detection team can use BigQuery to analyze large datasets of credit card transactions, identifying patterns and anomalies that may indicate fraudulent activity. With the data being encrypted, Operators need to decrypt the data before they can analyze it. This extra step can be cumbersome and time-consuming, especially for non-technical Operators.

The user story is as follows:

Transactions are sent to Vault Transform Secret Engine, which encrypts the data.

As an Operator, I want to be able to query the encrypted data in BigQuery without needing to decrypt it first, so that I can analyze the data more efficiently. I can use original credit card numbers as part of my queries. BigQuery will first call Vault transform API to encrypt the orginal credit card number, which will then be used to query the database, then decrypt the result and show the transactions to the Operator allowing me to decide whether the transaction is fraudulent or not.

## solution

The solution is to create a custom BigQuery function that integrates with the Hashicorp Vault Transform Secret Engine. This function will handle the encryption and decryption of sensitive data, allowing Operators to query encrypted data directly in BigQuery without needing to manually decrypt it.

The function should be hosted on Google Cloud Functions, which will allow it to be easily accessible from BigQuery. The function will take the original credit card number as input, call the Vault Transform Secret Engine API to encrypt it, and return the encrypted value. When querying the database, BigQuery will use this function to encrypt the credit card number before executing the query.

When retrieving results, the function will also handle decryption of the data returned from BigQuery, allowing Operators to view the original credit card numbers in a secure manner.

## implementation
