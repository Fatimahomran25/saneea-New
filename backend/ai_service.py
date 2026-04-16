import os
import json
from openai import OpenAI

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
