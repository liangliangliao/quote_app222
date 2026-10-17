import os
import pytest
from fastapi.testclient import TestClient
from app import app, ScoreRequest, Motive, build_questions, parse_answers, RUBRIC

def motive(identifier="motive-a"):
    return {"id":identifier,"summary":"个人理由","personal_basis":"explicit","horizon":"long","materiality":"important","risk_warning":False,"evidence_ids":["source-1"],"directions":[],"unknowns":[],"counter_reason":"待核实反方","fact_status":"reported"}

def payload():
    return {"case_id":"case-1","rubric_version":RUBRIC,"motives":[motive()],"evidence":[{"id":"source-1","source":"selfReport","phase":"t0","recorded_at":"2026-10-14T08:00:00Z","body":{"text":"PRIVATE_SENTINEL"}}]}

def answer(name, score=2):
    return {"type":"score","name":name,"score":score,"confidence":.8,"probabilities":[{"label":str(i),"value":i,"probability":1 if i==2 else 0} for i in range(5)]}

def test_fixed_rubric_and_independent_name_mapping():
    questions,mapping=build_questions([Motive(**motive()),Motive(**motive("motive-b"))])
    assert len(questions)==8 and len(mapping)==8
    assert all(q["type"]=="score" and [v["label"] for v in q["levels"]]==list("01234") for q in questions)
    assert mapping["m1_personal_fit"]==("motive-b","personal_fit")

def test_order_is_irrelevant_and_missing_answer_is_unknown():
    _,mapping=build_questions([Motive(**motive())])
    parsed=parse_answers({"answers":[answer("m0_context_relevance"),answer("m0_personal_fit")]},mapping)["motive-a"]
    assert len(parsed)==4
    assert [x for x in parsed if x["dimension"]=="evidence_quality"][0]["score"] is None

def test_refusal_not_zero():
    _,mapping=build_questions([Motive(**motive())])
    parsed=parse_answers({"answers":[{"type":"refusal","name":"m0_personal_fit"}]},mapping)["motive-a"]
    assert parsed[0]["status"]=="refused" and parsed[0]["score"] is None

@pytest.mark.parametrize("response",[
    {"answers":[answer("forged")]},
    {"answers":[answer("m0_personal_fit"),answer("m0_personal_fit")]},
    {"answers":[answer("m0_personal_fit",3)]},
    {"answers":[answer("m0_personal_fit",True)]},
    {"answers":[answer("m0_personal_fit",float("nan"))]},
])
def test_malformed_scale_or_mapping_fails_closed(response):
    _,mapping=build_questions([Motive(**motive())])
    with pytest.raises(ValueError):parse_answers(response,mapping)

def test_request_cannot_reference_unsent_evidence():
    data=payload();data["motives"][0]["evidence_ids"]=["other-case"]
    with pytest.raises(ValueError):ScoreRequest(**data)

def test_auth_before_body_validation(monkeypatch):
    monkeypatch.setenv("WILL_MIRROR_ACCESS_TOKEN","unit-test-token-12345")
    client=TestClient(app)
    assert client.post("/v1/will-mirror/motives/score",json={"private":"SECRET"}).status_code==401
    assert client.get("/openapi.json").status_code==404

def test_validation_never_echoes_private_input(monkeypatch):
    monkeypatch.setenv("WILL_MIRROR_ACCESS_TOKEN","unit-test-token-12345")
    response=TestClient(app).post("/v1/will-mirror/motives/score",headers={"Authorization":"Bearer unit-test-token-12345"},json={"secret":"PRIVATE_SENTINEL"})
    assert response.status_code==422 and "PRIVATE_SENTINEL" not in response.text

def test_missing_server_key_is_explicit_not_fake_score(monkeypatch):
    monkeypatch.setenv("WILL_MIRROR_ACCESS_TOKEN","unit-test-token-12345");monkeypatch.delenv("OPENAI_API_KEY",raising=False)
    response=TestClient(app).post("/v1/will-mirror/motives/score",headers={"Authorization":"Bearer unit-test-token-12345"},json=payload())
    assert response.status_code==503 and "scores" not in response.json()
