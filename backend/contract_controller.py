from datetime import datetime

from firebase_service import (
    delete_request_contract_data,
    get_request_by_id,
    update_request_contract_data,
)
from contract_service import build_contract_data, render_contract_text


def generate_contract_from_data(request_data):
    contract_data = build_contract_data(request_data)
    contract_text = render_contract_text(contract_data)

    return {
        "success": True,
        "contractData": contract_data,
        "contractText": contract_text
    }


def generate_contract_from_request_id(request_id):
    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    result = generate_contract_from_data(request_data)
    # Save the generated contract immediately after it is created.
    update_request_contract_data(request_id, result["contractData"])
    result["requestData"] = request_data
    return result


def approve_contract(request_id, role):
    normalized_role = (role or "").strip().lower()

    if normalized_role not in ("client", "freelancer"):
        raise ValueError("role must be either 'client' or 'freelancer'")

    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    # Reuse existing contract data when available.
    contract_data = request_data.get("contractData")
    if not isinstance(contract_data, dict):
        contract_data = build_contract_data(request_data)

    approval_data = contract_data.get("approval")
    if not isinstance(approval_data, dict):
        approval_data = {}

    # Only update approval fields and keep the rest of the contract unchanged.
    updated_approval = dict(approval_data)
    updated_approval["clientApproved"] = (
        True if normalized_role == "client"
        else bool(updated_approval.get("clientApproved", False))
    )
    updated_approval["freelancerApproved"] = (
        True if normalized_role == "freelancer"
        else bool(updated_approval.get("freelancerApproved", False))
    )
    updated_approval["contractStatus"] = (
        "approved"
        if updated_approval["clientApproved"] and updated_approval["freelancerApproved"]
        else "pending_approval"
    )

    contract_data["approval"] = updated_approval
    update_request_contract_data(request_id, contract_data)

    return {
        "success": True,
        "requestId": request_id,
        "contractData": contract_data,
        "contractText": render_contract_text(contract_data),
        "contractStatus": updated_approval["contractStatus"]
    }


def cancel_approval(request_id, role):
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

    if role == "client":
        approval["clientApproved"] = False
    elif role == "freelancer":
        approval["freelancerApproved"] = False
    else:
        return {
            "success": False,
            "error": "Invalid role"
        }

    if approval.get("clientApproved") and approval.get("freelancerApproved"):
        approval["contractStatus"] = "approved"
    elif approval.get("clientApproved") or approval.get("freelancerApproved"):
        approval["contractStatus"] = "pending_approval"
    else:
        approval["contractStatus"] = "draft"

    contract_data["approval"] = approval
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

    request_data = get_request_by_id(request_id)

    if not request_data:
        return {
            "success": False,
            "error": "Request not found"
        }

    contract_data = request_data.get("contractData")
    if not isinstance(contract_data, dict):
        contract_data = build_contract_data(request_data)

    approval_data = contract_data.get("approval")
    if not isinstance(approval_data, dict):
        approval_data = {}

    updated_approval = dict(approval_data)
    updated_approval["contractStatus"] = "rejected"

    contract_data["approval"] = updated_approval
    update_request_contract_data(request_id, contract_data)

    return {
        "success": True,
        "requestId": request_id,
        "contractData": contract_data,
        "contractText": render_contract_text(contract_data),
        "contractStatus": updated_approval["contractStatus"]
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
        existing_contract_data = build_contract_data(request_data)

    existing_parties = existing_contract_data.get("parties")
    existing_meta = existing_contract_data.get("meta")
    existing_approval = existing_contract_data.get("approval")
    existing_service = existing_contract_data.get("service")
    existing_payment = existing_contract_data.get("payment")
    existing_timeline = existing_contract_data.get("timeline")
    existing_custom_clauses = existing_contract_data.get("customClauses")

    updated_contract_data = {
        "parties": dict(existing_parties) if isinstance(existing_parties, dict) else {},
        "meta": dict(existing_meta) if isinstance(existing_meta, dict) else {},
        "approval": dict(existing_approval) if isinstance(existing_approval, dict) else {},
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

    if "customClauses" in contract_data:
        raw_clauses = contract_data.get("customClauses")
        if isinstance(raw_clauses, list):
            updated_contract_data["customClauses"] = [
                dict(clause) for clause in raw_clauses if isinstance(clause, dict)
            ]
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
