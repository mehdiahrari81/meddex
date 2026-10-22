import base64

import pytest
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from pydantic import SecretStr


def test_identity_proof_is_nonce_bound_and_contains_no_private_key(client):
    private = ec.generate_private_key(ec.SECP256R1())
    client.app.state.settings.local_server_private_key = SecretStr(
        format(private.private_numbers().private_value, "064x")
    )
    challenge = "a" * 64
    response = client.get("/api/v1/local-server-identity", params={"challenge": challenge})
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    proof = response.json()
    assert set(proof) == {"public_key", "signature"}
    public = serialization.load_der_public_key(base64.b64decode(proof["public_key"]))
    assert isinstance(public, ec.EllipticCurvePublicKey)
    public.verify(
        base64.b64decode(proof["signature"]),
        ("mediexplain-local-server-v1\n" + challenge).encode(),
        ec.ECDSA(hashes.SHA256()),
    )
    with pytest.raises(InvalidSignature):
        public.verify(
            base64.b64decode(proof["signature"]),
            ("mediexplain-local-server-v1\n" + "b" * 64).encode(),
            ec.ECDSA(hashes.SHA256()),
        )
    assert (
        client.get("/api/v1/local-server-identity", params={"challenge": "invalid"}).status_code
        == 422
    )


def test_identity_is_disabled_without_key_and_in_production(client):
    client.app.state.settings.local_server_private_key = None
    assert (
        client.get("/api/v1/local-server-identity", params={"challenge": "a" * 64}).status_code
        == 404
    )
    client.app.state.settings.local_server_private_key = SecretStr("1" * 64)
    client.app.state.settings.environment = "production"
    assert (
        client.get("/api/v1/local-server-identity", params={"challenge": "a" * 64}).status_code
        == 404
    )
