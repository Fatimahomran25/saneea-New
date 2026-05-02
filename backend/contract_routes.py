from flask import Blueprint, jsonify, request, send_file
import os
import requests
from firebase_admin import firestore
import firebase_service
from firebase_service import get_request_by_id
from pdf_service import generate_contract_pdf

from contract_controller import (
    approve_termination,
    approve_contract,
    cancel_contract,
    cancel_termination,
    cancel_approval,
    delete_contract,
    disapprove_contract,
    generate_contract_from_data,
    generate_contract_from_request_id,
    reject_termination,
    request_termination,
    update_contract,
)


# Keep all contract endpoints together so server.py only handles app setup.
contract_routes = Blueprint("contract_routes", __name__)


@contract_routes.route("/generate-contract", methods=["POST"])
def generate_contract():
    try:
        data = request.get_json(force=True)
        result = generate_contract_from_data(data)
        return jsonify(result), 200

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/generate-contract-from-request-id", methods=["POST"])
def generate_contract_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        proposal_id = data.get("proposalId", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        result = generate_contract_from_request_id(request_id, proposal_id)
        return jsonify(result), 200

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/approve-contract", methods=["POST"])
def approve_contract_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        role = data.get("role", "")
        termination_mode = data.get("terminationMode", "")
        signature_data = data.get("signatureData", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        if not role:
            return jsonify({
                "success": False,
                "error": "role is required"
            }), 400

        result = approve_contract(request_id, role, signature_data)
        status_code = 200 if result.get("success") else 404
        return jsonify(result), status_code

    except ValueError as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 400

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/request-termination", methods=["POST"])
def request_termination_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        role = data.get("role", "")
        termination_mode = data.get("terminationMode", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        if not role:
            return jsonify({
                "success": False,
                "error": "role is required"
            }), 400

        result = request_termination(request_id, role, termination_mode)
        status_code = 200 if result.get("success") else 400
        return jsonify(result), status_code

    except ValueError as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 400

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/approve-termination", methods=["POST"])
def approve_termination_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        role = data.get("role", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        if not role:
            return jsonify({
                "success": False,
                "error": "role is required"
            }), 400

        result = approve_termination(request_id, role)
        status_code = 200 if result.get("success") else 400
        return jsonify(result), status_code

    except ValueError as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 400

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/reject-termination", methods=["POST"])
def reject_termination_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        role = data.get("role", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        if not role:
            return jsonify({
                "success": False,
                "error": "role is required"
            }), 400

        result = reject_termination(request_id, role)
        status_code = 200 if result.get("success") else 400
        return jsonify(result), status_code

    except ValueError as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 400

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/cancel-termination", methods=["POST"])
def cancel_termination_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        role = data.get("role", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        if not role:
            return jsonify({
                "success": False,
                "error": "role is required"
            }), 400

        result = cancel_termination(request_id, role)
        status_code = 200 if result.get("success") else 400
        return jsonify(result), status_code

    except ValueError as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 400

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/cancel-approval", methods=["POST"])
def cancel_approval_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        role = data.get("role", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        if not role:
            return jsonify({
                "success": False,
                "error": "role is required"
            }), 400

        result = cancel_approval(request_id, role)
        status_code = 200 if result.get("success") else 400
        return jsonify(result), status_code

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/disapprove-contract", methods=["POST"])
def disapprove_contract_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        role = data.get("role", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        if not role:
            return jsonify({
                "success": False,
                "error": "role is required"
            }), 400

        result = disapprove_contract(request_id, role)
        status_code = 200 if result.get("success") else 404
        return jsonify(result), status_code

    except ValueError as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 400

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/cancel-contract", methods=["POST"])
def cancel_contract_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        role = data.get("role", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        result = cancel_contract(request_id, role)
        status_code = 200 if result.get("success") else 400
        return jsonify(result), status_code

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/update-contract", methods=["POST"])
def update_contract_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")
        contract_data = data.get("contractData")
        role = data.get("role", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        if not isinstance(contract_data, dict):
            return jsonify({
                "success": False,
                "error": "contractData is required"
            }), 400

        result = update_contract(request_id, contract_data, role)
        status_code = 200 if result.get("success") else 404
        return jsonify(result), status_code

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/delete-contract", methods=["POST"])
def delete_contract_api():
    try:
        data = request.get_json(force=True)
        request_id = data.get("requestId", "")

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        result = delete_contract(request_id)
        status_code = 200 if result.get("success") else 404
        return jsonify(result), status_code

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500


@contract_routes.route("/download-contract-pdf", methods=["GET"])
def download_contract_pdf_api():
    try:
        request_id = request.args.get("requestId", "").strip()

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        request_data = get_request_by_id(request_id)

        if not request_data:
            return jsonify({
                "success": False,
                "error": "Request not found"
            }), 404

        contract_data = request_data.get("contractData")

        if not isinstance(contract_data, dict):
            return jsonify({
                "success": False,
                "error": "No contract found"
            }), 404

        approval = contract_data.get("approval", {})
        contract_status = str(approval.get("contractStatus", "")).strip().lower()
        client_approved = approval.get("clientApproved") is True
        freelancer_approved = approval.get("freelancerApproved") is True

        if (
            contract_status != "approved"
            or not client_approved
            or not freelancer_approved
        ):
            return jsonify({
                "success": False,
                "error": "Final contract PDF is only available after both parties approve"
            }), 400

        pdf_buffer = generate_contract_pdf(contract_data)

        return send_file(
            pdf_buffer,
            as_attachment=True,
            download_name=f"contract_{request_id}.pdf",
            mimetype="application/pdf"
        )

    except Exception as error:
        return jsonify({
            "success": False,
            "error": str(error)
        }), 500



MOYASAR_SECRET_KEY = "sk_test_c4eiqi5WGWheVnQFws8m6CEcLQqAebHyM64o46U1"


@contract_routes.route("/verify-payment", methods=["POST"])
def verify_payment_api():
    try:
        data = request.get_json(force=True)

        payment_id = str(data.get("paymentId", "")).strip()
        request_id = str(data.get("requestId", "")).strip()
        paid_by = str(data.get("paidBy", "")).strip()

        if not payment_id:
            return jsonify({"success": False, "error": "paymentId is required"}), 400

        if not request_id:
            return jsonify({"success": False, "error": "requestId is required"}), 400

        response = requests.get(
            f"https://api.moyasar.com/v1/payments/{payment_id}",
            auth=(MOYASAR_SECRET_KEY, "")
        )

        payment = response.json()

        if response.status_code < 200 or response.status_code >= 300:
            return jsonify({"success": False, "error": payment}), 400

        if payment.get("status") != "paid":
            return jsonify({
                "success": False,
                "paymentStatus": payment.get("status", "failed"),
                "deliveryStatus": "approved_awaiting_payment"
            }), 400

        firebase_service.db.collection("requests").document(request_id).update({
            "contractData.paymentData": {
                "paymentStatus": "paid",
                "transactionId": payment.get("id"),
                "paidAt": firestore.SERVER_TIMESTAMP,
                "paidBy": paid_by,
                "amount": payment.get("amount")
            },
            "contractData.deliveryData.status": "paid_delivered",
            "contractData.progressData.stage": "completed",
            "contractData.progressData.updatedAt": firestore.SERVER_TIMESTAMP,
            "contractData.progressData.updatedBy": "system",
            "contractData.approval.contractStatus": "completed"
        })

        return jsonify({
            "success": True,
            "paymentStatus": "paid",
            "deliveryStatus": "paid_delivered"
        }), 200

    except Exception as error:
        return jsonify({"success": False, "error": str(error)}), 500