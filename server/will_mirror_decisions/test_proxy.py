import http.client
import json
import threading
import unittest

from proxy import MODEL, ProxyServer, validated_request, validated_answers


def request_data():
    return {"model": MODEL, "input": json.dumps({
        "caseId": "c", "phase": "t1", "evidence": [{"id": "e", "text": "private"}],
        "motives": [{"id": "m", "text": "a reason"}],
    }), "questions": [{"instructions": "client instructions are ignored"}]}


class ProxyTests(unittest.TestCase):
    def test_fixed_contract(self):
        value = validated_request(request_data())
        self.assertEqual(value["model"], MODEL)
        self.assertEqual(len(value["questions"]), 4)
        self.assertEqual(value["questions"][0]["name"], "m__personal_fit")
        self.assertEqual(len(value["questions"][0]["levels"]), 5)
        self.assertNotIn("client instructions", json.dumps(value))

    def test_reject_arbitrary_models_overflow_duplicate_ids_and_extra_private_data(self):
        value = request_data()
        value["model"] = "other"
        with self.assertRaises(ValueError):
            validated_request(value)
        for data in (
            {"caseId": "c", "phase": "t0", "evidence": [], "motives": [{"id": "m"}] * 26},
            {"caseId": "c", "phase": "t0", "evidence": [], "motives": [{"id": "m"}] * 2},
            {"caseId": "c", "phase": "t0", "evidence": [], "motives": [{"id": "m"}], "wholeVault": "private"},
        ):
            with self.assertRaises(ValueError):
                validated_request({"model": MODEL, "input": json.dumps(data)})

    def test_http_auth_minimal_response_and_safe_upstream_failure(self):
        token = "private-test-client-token-12345"
        calls = []

        def upstream(payload, key):
            calls.append(payload)
            if len(calls) == 2:
                raise OSError("SECRET_UPSTREAM_ERROR")
            return {"answers": [{"name": "m__personal_fit", "type": "refusal"}]}

        server = ProxyServer(("127.0.0.1", 0), "server-only-test-key", token, upstream)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            def post(auth):
                conn = http.client.HTTPConnection(*server.server_address, timeout=3)
                conn.request("POST", "/v1/will-mirror/decisions", json.dumps(request_data()), {"Authorization": auth, "Content-Type": "application/json"})
                response = conn.getresponse()
                status, body = response.status, response.read().decode()
                conn.close()
                return status, body
            self.assertEqual(post("wrong")[0], 401)
            self.assertEqual(calls, [])
            status, body = post("Bearer " + token)
            self.assertEqual(status, 200)
            self.assertEqual(set(json.loads(body)), {"answers"})
            status, body = post("Bearer " + token)
            self.assertEqual(status, 502)
            self.assertNotIn("SECRET", body)
            self.assertNotIn("server-only-test-key", body)
            for _ in range(8):
                post("Bearer " + token)
            self.assertEqual(post("Bearer " + token)[0], 429)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_client_token_is_not_upstream_key(self):
        with self.assertRaises(ValueError):
            ProxyServer(("127.0.0.1", 0), "sk-should-remain-server-side", "sk-should-remain-server-side")

    def test_answers_are_bound_to_requested_motive_and_dimension(self):
        payload = validated_request(request_data())
        valid = {"name": "m__personal_fit", "type": "refusal"}
        self.assertEqual(validated_answers({"answers": [valid]}, payload)["answers"], [valid])
        for answers in [[valid, valid], [{"name": "another__personal_fit", "type": "score"}], [{"name": "m__personal_fit", "type": "other"}]]:
            with self.assertRaises(ValueError):
                validated_answers({"answers": answers}, payload)


if __name__ == "__main__":
    unittest.main()
