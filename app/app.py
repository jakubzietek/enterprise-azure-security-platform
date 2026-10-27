import os
from datetime import datetime, timezone

from flask import Flask, jsonify
from azure.identity import ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import HttpResponseError
from azure.keyvault.secrets import SecretClient
import mssql_python


app = Flask(__name__)

storage_account_name = os.environ["STORAGE_ACCOUNT_NAME"]
container_name = os.environ["STORAGE_CONTAINER_NAME"]
managed_identity_client_id = os.environ["AZURE_CLIENT_ID"]
key_vault_uri = os.environ["KEY_VAULT_URI"]
sql_server = os.environ["SQL_SERVER_FQDN"]
sql_database = os.environ["SQL_DATABASE_NAME"]

credential = ManagedIdentityCredential(
    client_id=managed_identity_client_id
)

secret_client = SecretClient(
    vault_url=key_vault_uri,
    credential=credential,
)

blob_service_client = BlobServiceClient(
    account_url=f"https://{storage_account_name}.blob.core.windows.net",
    credential=credential,
)

container_client = blob_service_client.get_container_client(container_name)


@app.get("/health")
def health():
    return jsonify({
        "status": "ok"
    })


@app.get("/storage-test")
def storage_test():
    blob_name = "m5-validation.txt"

    payload = (
        f"M5 managed identity validation\n"
        f"timestamp={datetime.now(timezone.utc).isoformat()}\n"
    )

    try:
        blob_client = container_client.get_blob_client(blob_name)

        blob_client.upload_blob(
            payload,
            overwrite=True,
        )

        downloaded = (
            blob_client
            .download_blob()
            .readall()
            .decode("utf-8")
        )

        return jsonify({
            "status": "success",
            "authentication": "managed-identity",
            "storage_account": storage_account_name,
            "container": container_name,
            "blob": blob_name,
            "content": downloaded,
        })

    except Exception as exc:
        app.logger.exception("Storage validation failed")

        return jsonify({
            "status": "error",
            "error_type": type(exc).__name__,
        }), 500

@app.get("/storage-negative-test")
def storage_negative_test():
    try:
        list(blob_service_client.list_containers())

        return jsonify({
            "status": "failure",
            "message": "Managed identity unexpectedly listed account containers."
        }), 500

    except HttpResponseError as exc:
        if exc.status_code == 403:
            return jsonify({
                "status": "success",
                "test": "least-privilege",
                "expected_result": "403 Forbidden",
                "message": "Managed identity cannot enumerate the Storage Account."
            })

        return jsonify({
            "status": "error",
            "status_code": exc.status_code,
            "error_type": type(exc).__name__
        }), 500

@app.get("/keyvault-test")
def keyvault_test():
    try:
        secret = secret_client.get_secret("m5-validation")

        return jsonify({
            "status": "success",
            "authentication": "managed-identity",
            "secret_name": secret.name,
            "secret_version": secret.properties.version,
            "secret_value_exposed": False,
        })

    except Exception as exc:
        app.logger.exception("Key Vault validation failed")

        return jsonify({
            "status": "error",
            "error_type": type(exc).__name__,
        }), 500

@app.get("/sql-test")
def sql_test():
    connection = None
    cursor = None

    try:
        connection_string = (
            f"Server={sql_server};"
            f"Database={sql_database};"
            "Authentication=ActiveDirectoryMSI;"
            f"UID={managed_identity_client_id};"
            "Encrypt=yes;"
            "TrustServerCertificate=no;"
        )

        connection = mssql_python.connect(connection_string)
        cursor = connection.cursor()

        cursor.execute(
            """
            INSERT INTO dbo.m5_validation (message)
            VALUES (%(message)s)
            """,
            {
                "message": "M5 managed identity SQL validation"
            },
        )

        connection.commit()

        cursor.execute(
            """
            SELECT TOP 1
                id,
                message,
                created_at
            FROM dbo.m5_validation
            ORDER BY id DESC
            """
        )

        row = cursor.fetchone()

        cursor.execute("SELECT USER_NAME()")
        connected_as = cursor.fetchone()[0]

        return jsonify({
            "status": "success",
            "authentication": "managed-identity",
            "connected_as": connected_as,
            "database": sql_database,
            "row": {
                "id": row[0],
                "message": row[1],
                "created_at": str(row[2]),
            },
        })

    except Exception as exc:
        app.logger.exception("SQL validation failed")

        return jsonify({
            "status": "error",
            "error_type": type(exc).__name__,
        }), 500

    finally:
        if cursor:
            cursor.close()

        if connection:
            connection.close()

@app.get("/sql-negative-test")
def sql_negative_test():
    connection = None
    cursor = None

    try:
        connection_string = (
            f"Server={sql_server};"
            f"Database={sql_database};"
            "Authentication=ActiveDirectoryMSI;"
            f"UID={managed_identity_client_id};"
            "Encrypt=yes;"
            "TrustServerCertificate=no;"
        )

        connection = mssql_python.connect(connection_string)
        cursor = connection.cursor()

        cursor.execute(
            """
            DELETE FROM dbo.m5_validation
            WHERE 1 = 0
            """
        )

        connection.rollback()

        return jsonify({
            "status": "failure",
            "message": "Managed identity unexpectedly had DELETE permission."
        }), 500

    except Exception as exc:
        error_message = str(exc).lower()

        if "delete" in error_message and "permission" in error_message:
            return jsonify({
                "status": "success",
                "test": "least-privilege",
                "expected_result": "DELETE denied",
                "message": "Managed identity cannot delete rows from dbo.m5_validation."
            })

        app.logger.exception("Unexpected SQL negative-test failure")

        return jsonify({
            "status": "error",
            "error_type": type(exc).__name__,
        }), 500

    finally:
        if cursor:
            cursor.close()

        if connection:
            connection.close()