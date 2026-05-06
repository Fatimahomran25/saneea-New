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
            "currency": "SAR",
            "paidAt": None
        },
        "paymentData": {
            "paymentStatus": "pending",
            "paymentCompleted": False,
            "paymentCompletedAt": "",
            "transactionId": "",
            "paidAt": "",
            "paidBy": "",
            "amount": ""
        },

        "progressData": {
            "stage": "started",
            "updatedAt": None,
            "updatedBy": ""
        },
        "deliveryData": {
            "status": "not_submitted",
            "previewImageUrls": [],
            "imageUrls": [],
            "imageItems": [],
            "fileItems": [],
            "finalWorkUrls": [],
            "fileNames": [],
            "linkUrls": [],
            "notes": "",
            "submittedAt": "",
            "submittedBy": "",
            "approvedByClient": False,
            "changesRequestedBy": "",
            "changesRequestedAt": "",
            "approvedBy": "",
            "approvedAt": "",
            "paidAt": ""
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
        },
        "signatures": {
            "clientSignature": None,
            "freelancerSignature": None
        }
    }


def render_contract_text(contract_data):
    return f"""
CONTRACT AGREEMENT

Contract Date: {contract_data["meta"]["createdAt"]}
Contract Status: {contract_data["approval"]["contractStatus"]}
Progress: {contract_data.get("progressData", {}).get("stage", "started")}
Delivery: {contract_data.get("deliveryData", {}).get("status", "not_submitted")}
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
