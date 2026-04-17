import os
import json
from openai import OpenAI
from datetime import datetime

from firebase_service import (
    create_approved_contract_chat_message,
    delete_request_contract_data,
    get_request_by_id,
    update_request_contract_data,
)
from contract_service import render_contract_text


client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

CONTRACT_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "title": {"type": "string"},
        "contractText": {"type": "string"},
        "summary": {
            "type": "array",
            "items": {"type": "string"},
            "maxItems": 8
        },
        "clauses": {
            "type": "array",
            "maxItems": 12,
            "items": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "title": {"type": "string"},
                    "text": {"type": "string"},
                    "category": {
                        "type": "string",
                        "enum": [
                            "scope",
                            "payment",
                            "timeline",
                            "revisions",
                            "delivery",
                            "confidentiality",
                            "liability",
                            "termination",
                            "other"
                        ]
                    },
                    "optional": {"type": "boolean"}
                },
                "required": ["title", "text", "category", "optional"]
            }
        },
        "warnings": {
            "type": "array",
            "items": {"type": "string"},
            "maxItems": 6
        }
    },
    "required": ["title", "contractText", "summary", "clauses", "warnings"]
}


def generate_contract_ai(data):
    prompt = f"""
Create a professional freelance contract draft using these inputs:

Client: {data.get('client', 'Client')}
Freelancer: {data.get('freelancer', 'Freelancer')}
Service Type: {data.get('service_type', 'Not specified')}
Project Description: {data.get('description', 'Not specified')}
Budget: {data.get('amount', 'Not specified')}
Currency: {data.get('currency', 'Not specified')}
Deadline: {data.get('deadline', 'Not specified')}
Extra Requirements: {data.get('extra_requirements', 'None')}

Instructions:
- Write clearly and professionally.
- Keep the language readable for non-lawyers.
- Do not invent jurisdiction-specific legal claims.
- Use neutral wording when details are missing.
- Return output strictly matching the JSON schema.
"""

    response = client.responses.create(
        model="gpt-5.4",
        input=[
            {
                "role": "system",
                "content": "You are a professional contract drafting assistant."
            },
            {
                "role": "user",
                "content": prompt
            }
        ],
        text={
            "format": {
                "type": "json_schema",
                "name": "generated_contract",
                "strict": True,
                "schema": CONTRACT_SCHEMA
            }
        }
    )

    raw_text = response.output_text

    if not raw_text:
        raise ValueError("Empty AI response")

    try:
        return json.loads(raw_text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid AI JSON response: {str(e)}")


def generate_contract_from_data(request_data):
    print("🔥 AI شغال")

    ai_result = generate_contract_ai({
        "client": request_data.get("clientName") or request_data.get("client"),
        "freelancer": request_data.get("freelancerName") or request_data.get("freelancer"),
        "service_type": request_data.get("serviceType") or request_data.get("category"),
        "description": request_data.get("description"),
        "amount": request_data.get("amount") or request_data.get("budget"),
        "currency": request_data.get("currency"),
        "deadline": request_data.get("deadline"),
        "extra_requirements": request_data.get("extraRequirements"),
    })

    print("AI RESULT =>", ai_result)

    contract_data = {
        "parties": {
            "clientName": request_data.get("clientName") or request_data.get("client", "Client"),
            "freelancerName": request_data.get("freelancerName") or request_data.get("freelancer", "Freelancer"),
        },
        "meta": {
            "title": ai_result["title"],
            "summary": ai_result.get("summary", []),
            "warnings": ai_result.get("warnings", []),
            "source": "ai",
            "model": "gpt-5.4",
            "createdAt": datetime.now().strftime("%d/%m/%Y"),
        },
        "approval": {
            "clientApproved": False,
            "freelancerApproved": False,
            "contractStatus": "draft",
            "edited": False,
        },
        "signatures": {
            "clientSignature": None,
            "freelancerSignature": None,
        },
        "service": {
            "description": request_data.get("description"),
            "aiText": ai_result["contractText"],
        },
        "payment": {
            "amount": request_data.get("amount") or request_data.get("budget"),
            "currency": request_data.get("currency"),
        },
        "timeline": {
            "deadline": request_data.get("deadline"),
        },
        "customClauses": [
            {
                "title": clause.get("title", ""),
                "content": clause.get("text", ""),
                "category": clause.get("category", "other"),
                "optional": clause.get("optional", False),
                "source": "ai",
            }
            for clause in ai_result.get("clauses", [])
            if isinstance(clause, dict)
        ],
    }

    return {
        "success": True,
        "contractData": contract_data,
        "contractText": ai_result["contractText"],
        "summary": ai_result.get("summary", []),
    }


def generate_contract_from_request_id(request_id):
    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    result = generate_contract_from_data(request_data)
    update_request_contract_data(request_id, result["contractData"])
    result["requestData"] = request_data
    return result


def _normalize_signatures(signatures):
    raw_signatures = dict(signatures) if isinstance(signatures, dict) else {}
    return {
        "clientSignature": raw_signatures.get("clientSignature"),
        "freelancerSignature": raw_signatures.get("freelancerSignature"),
    }


def _normalize_clause_identity(clause):
    if not isinstance(clause, dict):
        return None

    return (
        str(clause.get("title", "")).strip(),
        str(clause.get("content", clause.get("text", ""))).strip(),
        str(clause.get("category", "")).strip(),
        bool(clause.get("optional", False)),
    )


def _normalize_custom_clauses(raw_clauses, existing_clauses):
    existing_source_by_identity = {}

    for clause in existing_clauses if isinstance(existing_clauses, list) else []:
        if not isinstance(clause, dict):
            continue

        identity = _normalize_clause_identity(clause)
        if identity is None:
            continue

        source = str(clause.get("source", "")).strip().lower()
        if source not in ("ai", "user"):
            if "category" in clause or "optional" in clause:
                source = "ai"
            else:
                source = "user"

        existing_source_by_identity[identity] = source

    normalized_clauses = []

    for clause in raw_clauses if isinstance(raw_clauses, list) else []:
        if not isinstance(clause, dict):
            continue

        normalized_clause = dict(clause)
        source = str(normalized_clause.get("source", "")).strip().lower()

        if source not in ("ai", "user"):
            identity = _normalize_clause_identity(normalized_clause)
            source = existing_source_by_identity.get(identity)

            if source not in ("ai", "user"):
                if "category" in normalized_clause or "optional" in normalized_clause:
                    source = "ai"
                else:
                    source = "user"

        normalized_clause["source"] = source
        normalized_clauses.append(normalized_clause)

    return normalized_clauses


def approve_contract(request_id, role, signature_data):
    normalized_role = (role or "").strip().lower()
    normalized_signature_data = (
        signature_data.strip() if isinstance(signature_data, str) else ""
    )

    if normalized_role not in ("client", "freelancer"):
        raise ValueError("role must be either 'client' or 'freelancer'")

    if not normalized_signature_data:
        raise ValueError("signatureData is required")

    print("🔥 APPROVE HIT", request_id, normalized_role)

    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    contract_data = request_data.get("contractData")
    if not isinstance(contract_data, dict):
        generated = generate_contract_from_data(request_data)
        contract_data = generated["contractData"]

    approval = contract_data.get("approval", {})
    previous_contract_status = str(
        approval.get("contractStatus", "")
    ).strip().lower()
    signatures = _normalize_signatures(contract_data.get("signatures"))

    if normalized_role == "client":
        signatures["clientSignature"] = normalized_signature_data
    else:
        signatures["freelancerSignature"] = normalized_signature_data

    approval["clientApproved"] = bool(signatures.get("clientSignature"))
    approval["freelancerApproved"] = bool(signatures.get("freelancerSignature"))

    if approval.get("clientApproved") and approval.get("freelancerApproved"):
        approval["contractStatus"] = "approved"
    else:
        approval["contractStatus"] = "pending_approval"

    contract_data["approval"] = approval
    contract_data["signatures"] = signatures
    update_request_contract_data(request_id, contract_data)

    contract_text = render_contract_text(contract_data)

    if (
        approval.get("contractStatus") == "approved" and
        previous_contract_status != "approved"
    ):
        create_approved_contract_chat_message(
            request_id=request_id,
            request_data=request_data,
            contract_data=contract_data,
            sender_role=normalized_role,
            contract_text=contract_text,
        )

    return {
        "success": True,
        "contractData": contract_data,
        "contractStatus": approval["contractStatus"],
        "contractText": contract_text,
    }


def cancel_approval(request_id, role):
    normalized_role = (role or "").strip().lower()

    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    contract_data = request_data.get("contractData")
    if not isinstance(contract_data, dict):
        return {
            "success": False,
            "error": "No contract found"
        }

    approval = contract_data.get("approval", {})
    signatures = _normalize_signatures(contract_data.get("signatures"))

    if normalized_role == "client":
        signatures["clientSignature"] = None
    elif normalized_role == "freelancer":
        signatures["freelancerSignature"] = None
    else:
        return {
            "success": False,
            "error": "Invalid role"
        }

    approval["clientApproved"] = bool(signatures.get("clientSignature"))
    approval["freelancerApproved"] = bool(signatures.get("freelancerSignature"))

    if approval.get("clientApproved") and approval.get("freelancerApproved"):
        approval["contractStatus"] = "approved"
    elif approval.get("clientApproved") or approval.get("freelancerApproved"):
        approval["contractStatus"] = "pending_approval"
    else:
        approval["contractStatus"] = "draft"

    contract_data["approval"] = approval
    contract_data["signatures"] = signatures
    update_request_contract_data(request_id, contract_data)

    return {
        "success": True,
        "contractData": contract_data,
        "contractStatus": approval["contractStatus"]
    }


def disapprove_contract(request_id, role):
    normalized_role = (role or "").strip().lower()

    if normalized_role not in ("client", "freelancer"):
        raise ValueError("role must be either 'client' or 'freelancer'")

    print("🔥 REJECT HIT", request_id, normalized_role)

    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    contract_data = request_data.get("contractData")
    if not isinstance(contract_data, dict):
        generated = generate_contract_from_data(request_data)
        contract_data = generated["contractData"]

    approval = contract_data.get("approval", {})
    approval["contractStatus"] = "rejected"

    contract_data["approval"] = approval
    update_request_contract_data(request_id, contract_data)

    return {
        "success": True,
        "contractData": contract_data,
        "contractStatus": "rejected",
        "contractText": render_contract_text(contract_data),
    }


def request_termination(request_id, role):
    normalized_role = (role or "").strip().lower()

    if normalized_role not in ("client", "freelancer"):
        raise ValueError("role must be either 'client' or 'freelancer'")

    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    contract_data = request_data.get("contractData")
    if not isinstance(contract_data, dict):
        return {
            "success": False,
            "error": "No contract found"
        }

    approval = contract_data.get("approval")
    if not isinstance(approval, dict):
        approval = {}

    contract_status = str(approval.get("contractStatus", "")).strip().lower()
    if contract_status != "approved":
        return {
            "success": False,
            "error": "Only approved contracts can be terminated"
        }

    termination = approval.get("termination")
    if not isinstance(termination, dict):
        termination = {}

    approval["termination"] = {
        **termination,
        "requested": True,
        "requestedBy": normalized_role,
        "requestedAt": datetime.now().isoformat(),
        "approved": False,
        "approvedBy": "",
        "approvedAt": "",
    }
    approval["contractStatus"] = "termination_pending"

    contract_data["approval"] = approval
    update_request_contract_data(request_id, contract_data)

    return {
        "success": True,
        "contractData": contract_data,
        "contractStatus": approval["contractStatus"],
        "contractText": render_contract_text(contract_data),
    }


def approve_termination(request_id, role):
    normalized_role = (role or "").strip().lower()

    if normalized_role not in ("client", "freelancer"):
        raise ValueError("role must be either 'client' or 'freelancer'")

    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    contract_data = request_data.get("contractData")
    if not isinstance(contract_data, dict):
        return {
            "success": False,
            "error": "No contract found"
        }

    approval = contract_data.get("approval")
    if not isinstance(approval, dict):
        approval = {}

    contract_status = str(approval.get("contractStatus", "")).strip().lower()
    if contract_status != "termination_pending":
        return {
            "success": False,
            "error": "No termination request is pending"
        }

    termination = approval.get("termination")
    if not isinstance(termination, dict) or termination.get("requested") is not True:
        return {
            "success": False,
            "error": "No termination request found"
        }

    requested_by = str(termination.get("requestedBy", "")).strip().lower()
    if requested_by == normalized_role:
        return {
            "success": False,
            "error": "The requester cannot approve their own termination request"
        }

    approval["termination"] = {
        **termination,
        "approved": True,
        "approvedBy": normalized_role,
        "approvedAt": datetime.now().isoformat(),
    }
    approval["contractStatus"] = "terminated"

    contract_data["approval"] = approval
    update_request_contract_data(request_id, contract_data)

    return {
        "success": True,
        "contractData": contract_data,
        "contractStatus": approval["contractStatus"],
        "contractText": render_contract_text(contract_data),
    }


def cancel_termination(request_id, role):
    normalized_role = (role or "").strip().lower()

    if normalized_role not in ("client", "freelancer"):
        raise ValueError("role must be either 'client' or 'freelancer'")

    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    contract_data = request_data.get("contractData")
    if not isinstance(contract_data, dict):
        return {
            "success": False,
            "error": "No contract found"
        }

    approval = contract_data.get("approval")
    if not isinstance(approval, dict):
        approval = {}

    contract_status = str(approval.get("contractStatus", "")).strip().lower()
    if contract_status != "termination_pending":
        return {
            "success": False,
            "error": "No termination request is pending"
        }

    termination = approval.get("termination")
    if not isinstance(termination, dict) or termination.get("requested") is not True:
        return {
            "success": False,
            "error": "No termination request found"
        }

    approval["termination"] = {
        "requested": False,
        "requestedBy": "",
        "requestedAt": "",
        "approved": False,
        "approvedBy": "",
        "approvedAt": "",
        "cancelledBy": normalized_role,
        "cancelledAt": datetime.now().isoformat(),
    }
    approval["contractStatus"] = "approved"

    contract_data["approval"] = approval
    update_request_contract_data(request_id, contract_data)

    return {
        "success": True,
        "contractData": contract_data,
        "contractStatus": approval["contractStatus"],
        "contractText": render_contract_text(contract_data),
    }


def update_contract(request_id, contract_data, role=""):
    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    existing_contract_data = request_data.get("contractData")
    if not isinstance(existing_contract_data, dict):
        generated = generate_contract_from_data(request_data)
        existing_contract_data = generated["contractData"]

    existing_parties = existing_contract_data.get("parties")
    existing_meta = existing_contract_data.get("meta")
    existing_approval = existing_contract_data.get("approval")
    existing_signatures = existing_contract_data.get("signatures")
    existing_service = existing_contract_data.get("service")
    existing_payment = existing_contract_data.get("payment")
    existing_timeline = existing_contract_data.get("timeline")
    existing_custom_clauses = existing_contract_data.get("customClauses")

    updated_contract_data = {
        "parties": dict(existing_parties) if isinstance(existing_parties, dict) else {},
        "meta": dict(existing_meta) if isinstance(existing_meta, dict) else {},
        "approval": dict(existing_approval) if isinstance(existing_approval, dict) else {},
        "signatures": _normalize_signatures(existing_signatures),
        "service": dict(existing_service) if isinstance(existing_service, dict) else {},
        "payment": dict(existing_payment) if isinstance(existing_payment, dict) else {},
        "timeline": dict(existing_timeline) if isinstance(existing_timeline, dict) else {},
        "customClauses": list(existing_custom_clauses) if isinstance(existing_custom_clauses, list) else [],
    }

    if isinstance(contract_data.get("service"), dict):
        updated_contract_data["service"] = dict(contract_data["service"])

    if isinstance(contract_data.get("payment"), dict):
        updated_contract_data["payment"] = dict(contract_data["payment"])

    if isinstance(contract_data.get("timeline"), dict):
        updated_contract_data["timeline"] = dict(contract_data["timeline"])

    if isinstance(contract_data.get("meta"), dict):
        updated_contract_data["meta"].update(contract_data["meta"])

    if "customClauses" in contract_data:
        raw_clauses = contract_data.get("customClauses")
        if isinstance(raw_clauses, list):
            updated_contract_data["customClauses"] = _normalize_custom_clauses(
                raw_clauses,
                existing_custom_clauses,
            )
        else:
            updated_contract_data["customClauses"] = []

    normalized_role = (role or "").strip().lower()
    updated_approval = updated_contract_data["approval"]
    had_previous_approval = bool(updated_approval.get("clientApproved")) or bool(
        updated_approval.get("freelancerApproved")
    )
    was_edited = updated_approval.get("contractStatus") == "edited" or bool(
        updated_approval.get("edited")
    )

    if had_previous_approval or was_edited:
        updated_approval["clientApproved"] = False
        updated_approval["freelancerApproved"] = False
        updated_approval["contractStatus"] = "edited"
        updated_approval["edited"] = True
        updated_approval["lastEditedBy"] = normalized_role
        updated_approval["lastEditedAt"] = datetime.now().isoformat()
        updated_contract_data["signatures"] = {
            "clientSignature": None,
            "freelancerSignature": None,
        }
    else:
        updated_approval["contractStatus"] = (
            updated_approval.get("contractStatus") or "draft"
        )
        updated_approval["edited"] = False

    update_request_contract_data(request_id, updated_contract_data)

    return {
        "success": True,
        "contractData": updated_contract_data,
        "contractText": render_contract_text(updated_contract_data)
    }


def delete_contract(request_id):
    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    delete_request_contract_data(request_id)

    return {
        "success": True
    }
