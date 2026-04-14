from datetime import datetime


def build_contract_data(request):
    return {
        "parties": {
            "clientName": request.get("clientName", ""),
            "freelancerName": request.get("freelancerName", "")
        },
        "service": {
            "description": request.get("description", "")
        },
        "payment": {
            "amount": request.get("budget", 0),
            "currency": "SAR"
        },
        "timeline": {
            "deadline": request.get("deadline", "")
        },
        "meta": {
            "createdAt": datetime.now().strftime("%d/%m/%Y")
        },
        "approval": {
            "clientApproved": False,
            "freelancerApproved": False,
            "contractStatus": "draft"
        }
    }


def render_contract_text(contract_data):
    return f"""
CONTRACT AGREEMENT

Contract Date: {contract_data["meta"]["createdAt"]}
Contract Status: {contract_data["approval"]["contractStatus"]}

This agreement is made between:

First Party (Client): {contract_data["parties"]["clientName"]}
Second Party (Freelancer): {contract_data["parties"]["freelancerName"]}

1. Service Description
The second party agrees to provide the following service:
{contract_data["service"]["description"]}

2. Payment
The first party agrees to pay a total amount of:
{contract_data["payment"]["amount"]} {contract_data["payment"]["currency"]}

3. Deadline
The service must be completed before:
{contract_data["timeline"]["deadline"]}

4. Agreement Basis
This contract is based on the accepted request details agreed upon by both parties.

5. Amendments
Any future changes to this agreement must be accepted by both parties.

6. Approval Status
Client Approved: {contract_data["approval"]["clientApproved"]}
Freelancer Approved: {contract_data["approval"]["freelancerApproved"]}

7. Agreement
Both parties agree to the terms stated above.
""".strip()