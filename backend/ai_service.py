import os
import json
from datetime import datetime
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

CONTRACT_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "parties": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "clientName": {"type": "string"},
                "freelancerName": {"type": "string"}
            },
            "required": ["clientName", "freelancerName"]
        },
        "service": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "description": {"type": "string"}
            },
            "required": ["description"]
        },
        "payment": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "amount": {"type": "string"},
                "currency": {"type": "string"}
            },
            "required": ["amount", "currency"]
        },
        "timeline": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "deadline": {"type": "string"}
            },
            "required": ["deadline"]
        },
        "meta": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "title": {"type": "string"},
                "createdAt": {"type": "string"}
            },
            "required": ["title", "createdAt"]
        },
        "approval": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "contractStatus": {
                    "type": "string",
                    "enum": ["draft", "pending_approval", "approved", "rejected", "edited"]
                }
            },
            "required": ["contractStatus"]
        },
        "signatures": {
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "clientSignature": {"type": ["string", "null"]},
                "freelancerSignature": {"type": ["string", "null"]}
            },
            "required": ["clientSignature", "freelancerSignature"]
        },
        "customClauses": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "title": {
                        "type": "string",
                        "enum": [
                            "Services",
                            "Payment Terms",
                            "Revisions",
                            "Delivery",
                            "Confidentiality"
                        ]
                    },
                    "content": {"type": "string"},
                    "source": {
                        "type": "string",
                        "enum": ["ai", "user"]
                    }
                },
                "required": ["title", "content", "source"]
            }
        }
    },
    "required": [
        "parties",
        "service",
        "payment",
        "timeline",
        "meta",
        "approval",
        "signatures",
        "customClauses"
    ]
}


def _safe_str(value, default="-"):
    if value is None:
        return default
    text = str(value).strip()
    return text if text else default


def _normalize_currency(value):
    text = _safe_str(value, "SAR").upper()
    return text


def _normalize_status(value):
    allowed = {"draft", "pending_approval", "approved", "rejected", "edited"}
    text = _safe_str(value, "draft").lower()
    return text if text in allowed else "draft"


def _clean_ai_result(result: dict, original_data: dict) -> dict:
    """
    يضمن أن الناتج النهائي متوافق مع الـ PDF حتى لو الـ AI رجع شيء ناقص.
    """
    client_name = _safe_str(original_data.get("client"), "Client")
    freelancer_name = _safe_str(original_data.get("freelancer"), "Freelancer")
    description = _safe_str(original_data.get("description"), "Not specified")
    amount = _safe_str(original_data.get("amount"), "Not specified")
    currency = _normalize_currency(original_data.get("currency"))
    deadline = _safe_str(original_data.get("deadline"), "Not specified")
    created_at = datetime.now().strftime("%Y-%m-%d")
    status = _normalize_status(original_data.get("contract_status"))

    cleaned = {
        "parties": {
            "clientName": _safe_str(
                result.get("parties", {}).get("clientName") if isinstance(result.get("parties"), dict) else None,
                client_name
            ),
            "freelancerName": _safe_str(
                result.get("parties", {}).get("freelancerName") if isinstance(result.get("parties"), dict) else None,
                freelancer_name
            ),
        },
        "service": {
            "description": _safe_str(
                result.get("service", {}).get("description") if isinstance(result.get("service"), dict) else None,
                description
            )
        },
        "payment": {
            "amount": _safe_str(
                result.get("payment", {}).get("amount") if isinstance(result.get("payment"), dict) else None,
                amount
            ),
            "currency": _normalize_currency(
                result.get("payment", {}).get("currency") if isinstance(result.get("payment"), dict) else currency
            )
        },
        "timeline": {
            "deadline": _safe_str(
                result.get("timeline", {}).get("deadline") if isinstance(result.get("timeline"), dict) else None,
                deadline
            )
        },
        "meta": {
            "title": _safe_str(
                result.get("meta", {}).get("title") if isinstance(result.get("meta"), dict) else None,
                "Freelance Contract Agreement"
            ),
            "createdAt": _safe_str(
                result.get("meta", {}).get("createdAt") if isinstance(result.get("meta"), dict) else None,
                created_at
            )
        },
        "approval": {
            "contractStatus": _normalize_status(
                result.get("approval", {}).get("contractStatus") if isinstance(result.get("approval"), dict) else status
            )
        },
        "signatures": {
            "clientSignature": (
                result.get("signatures", {}).get("clientSignature")
                if isinstance(result.get("signatures"), dict)
                else None
            ),
            "freelancerSignature": (
                result.get("signatures", {}).get("freelancerSignature")
                if isinstance(result.get("signatures"), dict)
                else None
            )
        },
        "customClauses": []
    }

    allowed_titles = {
        "services": "Services",
        "payment terms": "Payment Terms",
        "revisions": "Revisions",
        "delivery": "Delivery",
        "confidentiality": "Confidentiality"
    }

    raw_clauses = result.get("customClauses", [])
    if isinstance(raw_clauses, list):
        for clause in raw_clauses:
            if not isinstance(clause, dict):
                continue

            raw_title = str(clause.get("title", "")).strip().lower()
            mapped_title = allowed_titles.get(raw_title) or clause.get("title")
            content = _safe_str(clause.get("content"), "")
            source = str(clause.get("source", "ai")).strip().lower()

            if mapped_title not in allowed_titles.values():
                continue
            if not content:
                continue
            if source not in ("ai", "user"):
                source = "ai"

            cleaned["customClauses"].append({
                "title": mapped_title,
                "content": content,
                "source": source
            })

    return cleaned


def generate_contract_ai(data):
    created_at = datetime.now().strftime("%Y-%m-%d")

    prompt = f"""
Create a professional freelance contract draft and return ONLY valid JSON.

Input data:
- Client: {data.get('client', 'Client')}
- Freelancer: {data.get('freelancer', 'Freelancer')}
- Service Type: {data.get('service_type', 'Not specified')}
- Project Description: {data.get('description', 'Not specified')}
- Budget Amount: {data.get('amount', 'Not specified')}
- Currency: {data.get('currency', 'SAR')}
- Deadline: {data.get('deadline', 'Not specified')}
- Extra Requirements: {data.get('extra_requirements', 'None')}
- Created At: {created_at}

Rules:
1. Return JSON only.
2. Keep the language clear and professional.
3. Do not include markdown or explanations.
4. Fill the JSON exactly as required.
5. Put the main project summary inside service.description.
6. payment.amount must contain only the amount as readable text.
7. payment.currency must contain the currency code like SAR or USD.
8. approval.contractStatus should default to "draft".
9. signatures.clientSignature and signatures.freelancerSignature must be null.
10. customClauses should only use these titles exactly when relevant:
   - Services
   - Payment Terms
   - Revisions
   - Delivery
   - Confidentiality
11. For AI-generated clauses, source must be "ai".
12. If some details are missing, use neutral wording instead of inventing facts.
"""

    response = client.responses.create(
        model="gpt-5.4",
        input=[
            {
                "role": "system",
                "content": (
                    "You are a professional contract drafting assistant. "
                    "Return only valid JSON that matches the schema exactly."
                )
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
        parsed = json.loads(raw_text)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid AI JSON response: {str(e)}")

    return _clean_ai_result(parsed, data)