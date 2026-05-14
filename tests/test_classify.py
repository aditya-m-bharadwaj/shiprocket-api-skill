"""Smoke tests for the safety classifier in bin/shiprocket-api-skill.

Run with:
    python3 -m unittest discover tests

These tests are deliberately offline and stdlib-only — they load
bin/shiprocket-api-skill via importlib.machinery.SourceFileLoader and exercise
the classifier directly. No network, no token required.
"""

from __future__ import annotations

import importlib.machinery
import pathlib
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
LOADER = importlib.machinery.SourceFileLoader(
    "shiprocket_ctl", str(REPO_ROOT / "bin" / "shiprocket-api-skill")
)
sr = LOADER.load_module()


class TestNormalizePath(unittest.TestCase):
    def test_numeric_segments_become_id(self):
        self.assertEqual(sr._normalize_path("/orders/12345"), "/orders/{id}")

    def test_nested_numeric_segments(self):
        self.assertEqual(
            sr._normalize_path("/orders/12/items/77"),
            "/orders/{id}/items/{id}",
        )

    def test_string_segments_preserved(self):
        self.assertEqual(
            sr._normalize_path("/courier/track/awb/ABC123"),
            "/courier/track/awb/ABC123",
        )

    def test_strips_v1_external_prefix(self):
        self.assertEqual(sr._normalize_path("/v1/external/orders"), "/orders")
        self.assertEqual(
            sr._normalize_path("/v1/external/orders/12345"),
            "/orders/{id}",
        )

    def test_strips_v1_only_prefix(self):
        self.assertEqual(sr._normalize_path("/v1/foo"), "/foo")

    def test_does_not_strip_unrelated_prefix(self):
        # Only literal /v1/external or /v1 at the start.
        self.assertEqual(sr._normalize_path("/v10/foo"), "/v10/foo")
        self.assertEqual(sr._normalize_path("/foo/v1/bar"), "/foo/v1/bar")


class TestClassify(unittest.TestCase):
    def test_get_orders_is_read(self):
        cls, flags, _why = sr.classify("GET", "/orders")
        self.assertEqual(cls, "read")
        self.assertEqual(flags, [])

    def test_get_with_v1_external_prefix_is_read(self):
        cls, _flags, _why = sr.classify("GET", "/v1/external/orders")
        self.assertEqual(cls, "read")

    def test_assign_awb_is_billable(self):
        cls, flags, _why = sr.classify("POST", "/courier/assign/awb")
        self.assertEqual(cls, "billable")
        self.assertIn("--yes", flags)
        self.assertIn("--i-understand-billing", flags)

    def test_assign_awb_with_v1_prefix_is_billable(self):
        cls, flags, _why = sr.classify("POST", "/v1/external/courier/assign/awb")
        self.assertEqual(cls, "billable")
        self.assertIn("--i-understand-billing", flags)

    def test_generate_pickup_is_billable(self):
        cls, _flags, _why = sr.classify("POST", "/courier/generate/pickup")
        self.assertEqual(cls, "billable")

    def test_generate_label_is_billable(self):
        cls, _flags, _why = sr.classify("POST", "/courier/generate/label")
        self.assertEqual(cls, "billable")

    def test_generate_invoice_is_billable(self):
        cls, _flags, _why = sr.classify("POST", "/courier/generate/invoice")
        self.assertEqual(cls, "billable")

    def test_generate_manifest_is_billable(self):
        cls, _flags, _why = sr.classify("POST", "/courier/generate/manifest")
        self.assertEqual(cls, "billable")

    def test_print_label_is_billable(self):
        cls, _flags, _why = sr.classify("POST", "/orders/print/label")
        self.assertEqual(cls, "billable")

    def test_forward_shipment_is_billable(self):
        cls, _flags, _why = sr.classify("POST", "/shipments/create/forward-shipment")
        self.assertEqual(cls, "billable")

    def test_create_adhoc_order_is_mutating(self):
        # Creating the order record itself is free; AWB assign is the
        # billable commit point. Verify the distinction is encoded.
        cls, flags, _why = sr.classify("POST", "/orders/create/adhoc")
        self.assertEqual(cls, "mutating")
        self.assertEqual(flags, ["--yes"])

    def test_cancel_order_is_destructive(self):
        cls, flags, _why = sr.classify("POST", "/orders/cancel")
        self.assertEqual(cls, "destructive")
        self.assertIn("--confirm-id", flags)

    def test_cancel_awbs_is_destructive(self):
        cls, _flags, _why = sr.classify("POST", "/orders/cancel/shipment/awbs")
        self.assertEqual(cls, "destructive")

    def test_delete_product_is_destructive(self):
        cls, flags, _why = sr.classify("DELETE", "/products/12345")
        self.assertEqual(cls, "destructive")
        self.assertIn("--confirm-id", flags)

    def test_delete_with_string_tail(self):
        cls, _flags, _why = sr.classify("DELETE", "/products/some-sku")
        self.assertEqual(cls, "destructive")

    def test_auth_login_is_privilege(self):
        cls, flags, _why = sr.classify("POST", "/auth/login")
        self.assertEqual(cls, "privilege")
        self.assertIn("--allow-privilege", flags)

    def test_api_users_is_privilege(self):
        cls, _flags, _why = sr.classify("POST", "/api-users/create")
        self.assertEqual(cls, "privilege")

    def test_wallet_recharge_is_financial(self):
        cls, flags, _why = sr.classify("POST", "/wallet/recharge")
        self.assertEqual(cls, "financial")
        self.assertIn("--allow-financial", flags)

    def test_billing_endpoint_is_financial(self):
        cls, _flags, _why = sr.classify("POST", "/billing/invoices/pay")
        self.assertEqual(cls, "financial")

    def test_unknown_post_defaults_to_mutating(self):
        cls, flags, _why = sr.classify("POST", "/some/future/endpoint")
        self.assertEqual(cls, "mutating")
        self.assertEqual(flags, ["--yes"])

    def test_unknown_delete_defaults_to_destructive(self):
        cls, _flags, _why = sr.classify("DELETE", "/some/future/endpoint/42")
        self.assertEqual(cls, "destructive")

    def test_method_case_insensitive(self):
        cls_lower, _, _ = sr.classify("get", "/orders")
        cls_upper, _, _ = sr.classify("GET", "/orders")
        self.assertEqual(cls_lower, cls_upper)

    def test_update_order_is_mutating(self):
        cls, flags, _why = sr.classify("POST", "/orders/update")
        self.assertEqual(cls, "mutating")
        self.assertEqual(flags, ["--yes"])

    def test_add_pickup_is_mutating(self):
        cls, _flags, _why = sr.classify("POST", "/settings/company/addpickup")
        self.assertEqual(cls, "mutating")

    def test_serviceability_get_is_read(self):
        cls, _flags, _why = sr.classify("GET", "/courier/serviceability")
        self.assertEqual(cls, "read")

    def test_track_get_is_read(self):
        cls, _flags, _why = sr.classify("GET", "/courier/track/awb/ABC123")
        self.assertEqual(cls, "read")

    def test_financial_overrides_billable_match(self):
        # /wallet/recharge would otherwise not match anything specific; check
        # the financial-prefix gate fires before defaults.
        cls, _flags, _why = sr.classify("PUT", "/wallet/recharge/123")
        self.assertEqual(cls, "financial")

    def test_get_under_financial_prefix_is_still_read(self):
        # Financial gate only applies to non-GET methods.
        cls, _flags, _why = sr.classify("GET", "/wallet/recharge/history")
        self.assertEqual(cls, "read")


class TestPathValidation(unittest.TestCase):
    def test_rejects_traversal_dotdot(self):
        with self.assertRaises(sr.CtlError):
            sr._validate_path("/../../etc/passwd")

    def test_rejects_traversal_dot(self):
        with self.assertRaises(sr.CtlError):
            sr._validate_path("/./orders")

    def test_rejects_url_encoded_percent(self):
        with self.assertRaises(sr.CtlError):
            sr._validate_path("/orders/%2e%2e/etc")

    def test_rejects_unsupported_chars(self):
        for bad in ["/foo?x=1", "/foo#frag", "/foo bar", "/foo\\bar"]:
            with self.subTest(path=bad), self.assertRaises(sr.CtlError):
                sr._validate_path(bad)

    def test_accepts_normal_paths(self):
        for good in [
            "/orders",
            "/orders/12345",
            "/courier/track/awb/ABC123",
            "/settings/company/pickup",
            "/v1/external/orders",
        ]:
            with self.subTest(path=good):
                sr._validate_path(good)  # should not raise


class TestPrivilegePrefixBareRoots(unittest.TestCase):
    """Regression: privilege/financial prefixes must match the bare root path
    (e.g. POST /sub-users for the create endpoint), not just paths nested
    under it. Earlier _PRIVILEGE_PREFIXES tuple entries had trailing slashes,
    so /sub-users (no slash) fell through to mutating — a real safety hole."""

    def test_bare_sub_users_is_privilege(self):
        cls, flags, _ = sr.classify("POST", "/sub-users")
        self.assertEqual(cls, "privilege")
        self.assertIn("--allow-privilege", flags)

    def test_bare_users_is_privilege(self):
        cls, _flags, _ = sr.classify("POST", "/users")
        self.assertEqual(cls, "privilege")

    def test_bare_auth_is_privilege(self):
        cls, _flags, _ = sr.classify("POST", "/auth")
        self.assertEqual(cls, "privilege")

    def test_bare_payments_is_financial(self):
        cls, _flags, _ = sr.classify("POST", "/payments")
        self.assertEqual(cls, "financial")


class TestPlatformAndDisplay(unittest.TestCase):
    def test_no_gui_error_returns_ctlerror(self):
        err = sr._no_gui_error()
        self.assertIsInstance(err, sr.CtlError)

    def test_has_display_returns_bool(self):
        self.assertIsInstance(sr._has_display(), bool)

    def test_platform_known(self):
        self.assertIn(sr._platform(), {"macos", "linux", "windows", "unknown"})


class TestJwtPayload(unittest.TestCase):
    def test_decodes_well_formed_jwt(self):
        # A JWT with header.payload.signature where payload is a known dict.
        # Header and signature can be anything — we only decode the payload.
        import base64
        import json as _json

        header = base64.urlsafe_b64encode(b'{"alg":"HS256","typ":"JWT"}').rstrip(b"=").decode()
        payload_obj = {"id": 42, "email": "a@b.com", "exp": 1900000000,
                       "first_name": "Ada", "last_name": "Lovelace",
                       "company_id": 99}
        payload = base64.urlsafe_b64encode(
            _json.dumps(payload_obj).encode()
        ).rstrip(b"=").decode()
        sig = "sig"
        token = f"{header}.{payload}.{sig}"
        out = sr._decode_jwt_payload(token)
        self.assertIsNotNone(out)
        self.assertEqual(out["id"], 42)
        self.assertEqual(out["email"], "a@b.com")

    def test_returns_none_for_malformed_jwt(self):
        self.assertIsNone(sr._decode_jwt_payload("not-a-jwt"))
        self.assertIsNone(sr._decode_jwt_payload("only.two"))


if __name__ == "__main__":
    unittest.main()
