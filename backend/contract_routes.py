from flask import Blueprint, jsonify, request

from contract_controller import (
    approve_contract,
    cancel_approval,
    delete_contract,
    disapprove_contract,
    generate_contract_from_data,
    generate_contract_from_request_id,
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

        if not request_id:
            return jsonify({
                "success": False,
                "error": "requestId is required"
            }), 400

        result = generate_contract_from_request_id(request_id)
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

        result = approve_contract(request_id, role)
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


@contract_routes.route("/cancel-approval", methods=["POST"])
def cancel_approval_api():
    data = request.get_json(force=True)
    request_id = data.get("requestId", "")
    role = data.get("role", "")

    result = cancel_approval(request_id, role)
    return jsonify(result), 200


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
